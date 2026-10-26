-- Shared workspace foundation for KKP Invoice Studio.
-- Existing invoice/client records are retained and moved into one shared workspace.
create extension if not exists pgcrypto;

create table if not exists public.kkp_workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.kkp_workspace_members (
  workspace_id uuid not null references public.kkp_workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('admin','member')),
  joined_at timestamptz not null default now(),
  primary key (workspace_id,user_id)
);
create table if not exists public.kkp_workspace_invitations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.kkp_workspaces(id) on delete cascade,
  email text not null,
  invite_token text not null unique default encode(gen_random_bytes(24),'hex'),
  role text not null default 'member' check (role in ('admin','member')),
  invited_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  accepted_at timestamptz,
  unique (workspace_id, lower(email))
);

insert into public.kkp_workspaces(name)
select 'KKP Invoice Studio'
where not exists (select 1 from public.kkp_workspaces);

alter table public.kkp_invoices add column if not exists workspace_id uuid references public.kkp_workspaces(id);
alter table public.kkp_invoice_clients add column if not exists workspace_id uuid references public.kkp_workspaces(id);
alter table public.kkp_invoice_items add column if not exists workspace_id uuid references public.kkp_workspaces(id);
alter table public.kkp_invoice_audit_logs add column if not exists workspace_id uuid references public.kkp_workspaces(id);

-- Assign all existing records to the single shared workspace; no rows are deleted.
with w as (select id from public.kkp_workspaces order by created_at limit 1)
update public.kkp_invoices set workspace_id=(select id from w) where workspace_id is null;
with w as (select id from public.kkp_workspaces order by created_at limit 1)
update public.kkp_invoice_clients set workspace_id=(select id from w) where workspace_id is null;
with w as (select id from public.kkp_workspaces order by created_at limit 1)
update public.kkp_invoice_items i set workspace_id=(select id from w) where workspace_id is null;
with w as (select id from public.kkp_workspaces order by created_at limit 1)
update public.kkp_invoice_audit_logs a set workspace_id=(select id from w) where workspace_id is null;

-- Preserve access for existing data owners, granting them admin membership so
-- current accounts do not lose access during the workspace transition.
insert into public.kkp_workspace_members(workspace_id,user_id,role)
select w.id, u.user_id, 'admin'
from public.kkp_workspaces w
cross join (
  select created_by as user_id from public.kkp_invoices
  union select created_by from public.kkp_invoice_clients
  union select created_by from public.kkp_invoice_items
  union select created_by from public.kkp_invoice_audit_logs
) u
where w.id=(select id from public.kkp_workspaces order by created_at limit 1)
on conflict (workspace_id,user_id) do nothing;

create or replace function public.kkp_is_workspace_member(target_workspace uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp
as $$ select exists(select 1 from public.kkp_workspace_members m where m.workspace_id=target_workspace and m.user_id=(select auth.uid())) $$;

create or replace function public.kkp_is_workspace_admin(target_workspace uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp
as $$ select exists(select 1 from public.kkp_workspace_members m where m.workspace_id=target_workspace and m.user_id=(select auth.uid()) and m.role='admin') $$;

alter table public.kkp_workspaces enable row level security;
alter table public.kkp_workspace_members enable row level security;
alter table public.kkp_workspace_invitations enable row level security;

drop policy if exists "workspace members can view their workspace" on public.kkp_workspaces;
create policy "workspace members can view their workspace" on public.kkp_workspaces for select to authenticated using (public.kkp_is_workspace_member(id));
drop policy if exists "members can view workspace membership" on public.kkp_workspace_members;
create policy "members can view workspace membership" on public.kkp_workspace_members for select to authenticated using (public.kkp_is_workspace_member(workspace_id));
drop policy if exists "admins can manage workspace invitations" on public.kkp_workspace_invitations;
create policy "admins can manage workspace invitations" on public.kkp_workspace_invitations for all to authenticated using (public.kkp_is_workspace_admin(workspace_id)) with check (public.kkp_is_workspace_admin(workspace_id));

-- Admin-controlled invitation creation. Returns the generated invitation token.
create or replace function public.kkp_create_workspace_invitation(target_email text, target_role text default 'member')
returns table(invitation_token text, workspace_id uuid, expires_at timestamptz)
language plpgsql security definer set search_path=public,pg_temp
as $$
declare ws uuid; token text; expiry timestamptz;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if target_role not in ('member','admin') then raise exception 'Invalid role'; end if;
  select m.workspace_id into ws from public.kkp_workspace_members m
  where m.user_id=auth.uid() and m.role='admin' order by m.joined_at limit 1;
  if ws is null then raise exception 'Workspace admin access required'; end if;
  if target_email is null or length(trim(target_email))<5 or position('@' in target_email)=0 then raise exception 'Enter a valid email address'; end if;
  token:=encode(gen_random_bytes(24),'hex'); expiry:=now()+interval '7 days';
  insert into public.kkp_workspace_invitations(workspace_id,email,invite_token,role,invited_by,expires_at)
  values(ws,lower(trim(target_email)),token,target_role,auth.uid(),expiry)
  on conflict (workspace_id,lower(email)) do update set invite_token=excluded.invite_token,role=excluded.role,invited_by=excluded.invited_by,created_at=now(),expires_at=excluded.expires_at,accepted_at=null;
  return query select i.invite_token,i.workspace_id,i.expires_at from public.kkp_workspace_invitations i where i.workspace_id=ws and lower(i.email)=lower(trim(target_email));
end $$;

-- Accept a valid invitation only for the matching authenticated email.
create or replace function public.kkp_accept_workspace_invitation(token text)
returns uuid language plpgsql security definer set search_path=public,pg_temp
as $$
declare inv public.kkp_workspace_invitations%rowtype; user_email text;
begin
  if auth.uid() is null then raise exception 'Sign in to accept an invitation'; end if;
  select lower(email) into user_email from auth.users where id=auth.uid();
  select * into inv from public.kkp_workspace_invitations
    where invite_token=token and lower(email)=user_email and accepted_at is null and expires_at>now()
    for update;
  if inv.id is null then raise exception 'Invitation is invalid, expired, already used, or for a different email'; end if;
  insert into public.kkp_workspace_members(workspace_id,user_id,role) values(inv.workspace_id,auth.uid(),inv.role)
  on conflict(workspace_id,user_id) do nothing;
  update public.kkp_workspace_invitations set accepted_at=now() where id=inv.id;
  return inv.workspace_id;
end $$;

-- Replace per-user row access with workspace membership access.
drop policy if exists "users manage own invoices" on public.kkp_invoices;
drop policy if exists "users manage own invoice clients" on public.kkp_invoice_clients;
drop policy if exists "users manage own invoice items" on public.kkp_invoice_items;
drop policy if exists "Users can read own invoice audit logs" on public.kkp_invoice_audit_logs;
drop policy if exists "Users can insert own invoice audit logs" on public.kkp_invoice_audit_logs;

create policy "workspace members manage invoices" on public.kkp_invoices for all to authenticated
using (public.kkp_is_workspace_member(workspace_id)) with check (public.kkp_is_workspace_member(workspace_id));
create policy "workspace members manage clients" on public.kkp_invoice_clients for all to authenticated
using (public.kkp_is_workspace_member(workspace_id)) with check (public.kkp_is_workspace_member(workspace_id));
create policy "workspace members manage invoice items" on public.kkp_invoice_items for all to authenticated
using (public.kkp_is_workspace_member(workspace_id) and exists(select 1 from public.kkp_invoices i where i.id=invoice_id and i.workspace_id=kkp_invoice_items.workspace_id))
with check (public.kkp_is_workspace_member(workspace_id) and exists(select 1 from public.kkp_invoices i where i.id=invoice_id and i.workspace_id=kkp_invoice_items.workspace_id));
create policy "workspace members read audit logs" on public.kkp_invoice_audit_logs for select to authenticated using (public.kkp_is_workspace_member(workspace_id));
create policy "workspace members write audit logs" on public.kkp_invoice_audit_logs for insert to authenticated with check (public.kkp_is_workspace_member(workspace_id));

grant select on public.kkp_workspaces, public.kkp_workspace_members to authenticated;
grant select, insert, update, delete on public.kkp_workspace_invitations to authenticated;
grant execute on function public.kkp_is_workspace_member(uuid) to authenticated;
grant execute on function public.kkp_is_workspace_admin(uuid) to authenticated;
grant execute on function public.kkp_create_workspace_invitation(text,text) to authenticated;
grant execute on function public.kkp_accept_workspace_invitation(text) to authenticated;
