# KKP Invoice Studio

A minimal, responsive invoice workspace for Kiteskraft Productions entities and ACS-Adreneur Consultancy Solutions.

## Included
- Dashboard totals and recent invoices
- Invoice creation/editing, line items, discount and GST calculations
- Invoice statuses and search
- Client directory
- Company profiles and per-company logo selection placeholders
- Bank account settings
- A4 print layout (choose **Save as PDF** in the browser print dialog)
- JSON backup export/import
- Supabase-backed client/invoice storage with per-user access policies; local browser storage for bank accounts and logo preferences

## Run
Open `index.html` in a browser, or enable GitHub Pages from the repository settings to host the static app.

## Important prototype limitations
- Clients and invoices sync to the configured Supabase project for the signed-in user. Bank accounts and logo preferences remain local to the current browser. Team-wide sharing is not configured.
- Logo choices are currently text placeholders; add the original logo assets and wire them into the interface before production.
- Confirm legal entity details, GST treatment, and bank details with your accountant before issuing invoices.
- Team access and shared workspace membership are not implemented in this static starter.


## Supabase connection setup

The app now includes Supabase email/password authentication and database reads/writes for clients, invoices, and invoice line items. Before running it, the app is configured for the dedicated `KKP-INVOICE` Supabase project at `https://iddcwbfmrpnfikbkjazk.supabase.co`. The browser uses a Supabase publishable key (never use a `service_role` or secret key in browser code). In Supabase Authentication, configure the allowed redirect/site URLs for the URL where the app is hosted. Email confirmation may need to be completed before the first sign-in.

Database access uses the existing `kkp_invoice_clients`, `kkp_invoices`, and `kkp_invoice_items` tables and their row-level security policies. Each signed-in user currently sees their own records; shared company/team access needs organization-level policies and membership mapping. Bank accounts and logo preferences remain local to the browser in this prototype.
