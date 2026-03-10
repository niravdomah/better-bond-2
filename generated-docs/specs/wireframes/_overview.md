# Wireframes: BetterBond Commission Payments POC

## Summary
Three primary screens (Dashboard, Payment Management, Payments Made) plus five modal dialogs supporting park/unpark confirmation, payment batch initiation, success feedback, and demo reset. The application uses a persistent top navigation bar with the MortgageMax brand logo. Admin users have full access to all screens and actions; Viewer users have read-only access to Screen 1 and Screen 2 only.

## Screens

| # | Screen | Description | File | Role Access |
|---|--------|-------------|------|-------------|
| 1 | Dashboard | Aggregate KPI cards, bar charts (ready payments, parked payments, aging report), and agency summary grid with clickable rows | `screen-1-dashboard.md` | Admin + Viewer |
| 2 | Payment Management | Two grids (Main: ready payments; Parked: parked payments) with park/unpark/initiate actions and search filtering | `screen-2-payment-management.md` | Admin (full) + Viewer (read-only) |
| 3 | Payments Made | Completed payment batch list with invoice PDF download per row; search by agency or batch reference | `screen-3-payments-made.md` | Admin only |
| 4 | Park Confirmation Modal | Single or bulk park confirmation; shows agent/payment details before calling PUT /v1/payments/park | `screen-4-modal-park-confirmation.md` | Admin only |
| 5 | Unpark Confirmation Modal | Single or bulk unpark confirmation; shows agent/payment details before calling PUT /v1/payments/unpark | `screen-5-modal-unpark-confirmation.md` | Admin only |
| 6 | Initiate Payment Confirmation Modal | Summarises count and total value of all visible Main Grid payments before calling POST /v1/payment-batches | `screen-6-modal-initiate-confirmation.md` | Admin only |
| 7 | Initiate Payment Success Modal | Confirms batch created; provides "View Invoice" button to navigate to Screen 3 | `screen-7-modal-initiate-success.md` | Admin only |
| 8 | Reset Demo Confirmation Modal | Confirms destructive demo data reset before calling POST /demo/reset-demo | `screen-8-modal-reset-demo.md` | Admin only |

## Screen Flow

```
App Load
  |
  v
[Screen 1: Dashboard] <──────────────────────────────────────+
  |                                                           |
  | Agency row click (pre-filters Screen 2)                   |
  | Nav link                                                  |
  v                                                           |
[Screen 2: Payment Management] <───── Nav link ──────────────+
  |                                                           |
  | Park button (row)           [Screen 4: Park Modal]        |
  |   └─ Confirm ──────────────> PUT /v1/payments/park        |
  |                               └─ Success: row moves       |
  |                                  to Parked Grid           |
  |                                                           |
  | Park Selected               [Screen 4: Park Modal (bulk)] |
  |   └─ Confirm ──────────────> PUT /v1/payments/park        |
  |                                                           |
  | Unpark button (row)         [Screen 5: Unpark Modal]      |
  |   └─ Confirm ──────────────> PUT /v1/payments/unpark      |
  |                               └─ Success: row moves       |
  |                                  to Main Grid             |
  |                                                           |
  | Unpark Selected             [Screen 5: Unpark Modal (bulk)]
  |   └─ Confirm ──────────────> PUT /v1/payments/unpark      |
  |                                                           |
  | Initiate Payment            [Screen 6: Initiate Modal]    |
  |   └─ Confirm ──────────────> POST /v1/payment-batches     |
  |                               └─ Success:                 |
  |                               [Screen 7: Success Modal]   |
  |                                 └─ View Invoice ──────────+──────> [Screen 3: Payments Made]
  |                                 └─ Close → Screen 2       |
  |                                                           |
  | Nav link                                                  |
  v                                                           |
[Screen 3: Payments Made] ───────────── Nav link ────────────+
  |
  | [PDF] Download Invoice ──> POST /v1/payment-batches/{Id}/download-invoice-pdf
  |                              └─ Browser download / new tab

[Any Screen: Nav bar]
  |
  | Reset Demo (Admin only) ──> [Screen 8: Reset Demo Modal]
  |                               └─ Confirm ──> POST /demo/reset-demo
  |                                              └─ All screens refresh
```

## Design Notes

- **Navigation bar:** Persistent across all screens; contains MortgageMax logo (left), nav links (centre/right), Reset Demo button (Admin only, far right).
- **Role enforcement:** Screen 3 nav link is hidden/disabled for Viewer; action buttons on Screen 2 are rendered but visually greyed out for Viewer (not removed from DOM).
- **Currency formatting:** All ZAR amounts use en-ZA locale — "R 1 234 567,89" (space thousands separator, comma decimal separator).
- **Date formatting:** All dates DD/MM/YYYY (en-ZA locale).
- **Filter options:** Status and CommissionType dropdown values are derived dynamically from API response values — not hardcoded.
- **Batch ID column:** Blank/null for unbatched payments — not "0" or a placeholder.
- **Commission % column:** Calculated field: CommissionAmount ÷ BondAmount, formatted as a percentage (e.g., "0.945%"). Not returned by the API.
- **Initiate Payment scope:** Processes ALL payments currently visible in the Main Grid (respects active filters). One batch per agency per invocation.
- **Synchronous batch creation:** After Initiate Payment succeeds, the new batch is immediately visible on Screen 3 — no polling required.
- **Responsive layout:** All screens must be usable on desktop, tablet, and mobile (NFR1).
- **Light mode only:** No dark mode toggle (per intake manifest styling notes).
