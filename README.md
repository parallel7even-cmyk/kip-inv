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
- Local browser storage; no server credentials are embedded

## Run
Open `index.html` in a browser, or enable GitHub Pages from the repository settings to host the static app.

## Important prototype limitations
- Data is saved only in the current browser. It is not shared across users or devices.
- Logo choices are currently text placeholders; add the original logo assets and wire them into the interface before production.
- Confirm legal entity details, GST treatment, and bank details with your accountant before issuing invoices.
- Authentication, Supabase sync, team access and server-side permissions are not implemented in this static starter.


## Supabase connection setup

The app now includes Supabase email/password authentication and database reads/writes for clients, invoices, and invoice line items. Before running it, replace `PASTE_SUPABASE_PUBLISHABLE_KEY_HERE` in `index.html` with the project's **publishable** key (never use a `service_role` or secret key in browser code). The project URL is already configured. In Supabase Authentication, configure the allowed redirect/site URLs for the URL where the app is hosted. Email confirmation may need to be completed before the first sign-in.

Database access uses the existing `kkp_invoice_clients`, `kkp_invoices`, and `kkp_invoice_items` tables and their row-level security policies. Each signed-in user currently sees their own records; shared company/team access needs organization-level policies and membership mapping. Bank accounts and logo preferences remain local to the browser in this prototype.
