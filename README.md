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
