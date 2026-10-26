-- Preview migration: append-only invoice audit history.
create table if not exists public.kkp_invoice_audit_logs (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.kkp_invoices(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  action text not null,
  changes jsonb not null default '{}'::jsonb,
  actor_email text,
  created_at timestamptz not null default now()
);
create index if not exists kkp_invoice_audit_logs_invoice_created_at_idx
  on public.kkp_invoice_audit_logs (invoice_id, created_at desc);
alter table public.kkp_invoice_audit_logs enable row level security;
drop policy if exists "Users can read own invoice audit logs" on public.kkp_invoice_audit_logs;
create policy "Users can read own invoice audit logs"
  on public.kkp_invoice_audit_logs for select to authenticated
  using (created_by = auth.uid());
drop policy if exists "Users can insert own invoice audit logs" on public.kkp_invoice_audit_logs;
create policy "Users can insert own invoice audit logs"
  on public.kkp_invoice_audit_logs for insert to authenticated
  with check (created_by = auth.uid());
