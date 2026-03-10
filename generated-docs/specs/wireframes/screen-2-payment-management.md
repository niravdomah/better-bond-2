# Screen: Payment Management

## Purpose
Allows Admin users to park, unpark, and initiate payment batches. Viewer users see the same layout with all action buttons rendered but visually disabled. Displays two data grids: Main Grid (payments ready for processing) and Parked Grid (parked payments).

## Wireframe

```
+-----------------------------------------------------------------------------------+
|  [MortgageMax Logo]   Dashboard  Payment Management  Payments Made   [Reset Demo] |
|  (logo image, left)   (nav link)    (nav link, active) (nav link)   (Admin only)  |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  Payment Management                                                               |
|  ─────────────────────────────────────────────────────────────────────────────── |
|                                                                                   |
|  Filter Payments                                                                  |
|  +---------------------------------------------------+                           |
|  | [Claim Date...]  [Agency Name v]  [Status v]       | [Apply Filters]           |
|  +---------------------------------------------------+                           |
|  (Claim Date: free-text date input DD/MM/YYYY)                                    |
|  (Agency Name: dropdown, options from API)                                        |
|  (Status: dropdown, options from API dynamically)                                 |
|                                                                                   |
|  ── Main Grid: Payments Ready for Processing ─────────────────────────────────── |
|  [Park Selected]  (shown when >= 1 row selected; disabled for Viewer)             |
|  [Initiate Payment]  (always visible; disabled for Viewer)                        |
|                                                                                   |
|  +--+----------+--------+------------+------------+---------+------+------+------+-------+----------+--------+------+-----------+------+--------+
|  |[ ]| Agency  | Batch  | Claim Date | Agent Name | Bond    | Comm | Comm | Grant| Reg   | Bank     | Comm   | VAT  | Status    |      |        |
|  |   | Name    | ID     | DD/MM/YYYY | & Surname  | Amount  | Type | %    | Date | Date  |          | Amount |      |           |      |        |
|  +--+----------+--------+------------+------------+---------+------+------+------+-------+----------+--------+------+-----------+------+--------+
|  |[ ]| ABC     |        | 15/01/2026 | John Smith | R 1 2.. | Bond | 0.9% |05/12 | 10/01 | FNB      | R 11,..| R 1,.| Ready    |[Park]|        |
|  |[ ]| Coastal |        | 18/01/2026 | Jane Dube  | R 2 5.. | Bond | 0.9% |08/12 | 12/01 | ABSA     | R 23,..| R 3,.| Ready    |[Park]|        |
|  |[ ]| Platinum|        | 20/01/2026 | P. Nkosi   | R 1 8.. | Reg  | 0.9% |10/12 | 15/01 | Standard | R 17,..| R 2,.| Ready    |[Park]|        |
|  | ...                                                                         ...                                                             |
|  +-----------------------------------------------------------------------...------+
|  (all currency formatted R x xxx,xx; dates DD/MM/YYYY; Batch ID blank for unbatched)
|  (Park button disabled and greyed out for Viewer role)                            |
|                                                                                   |
|  ── Parked Grid: Parked Payments ─────────────────────────────────────────────── |
|  [Unpark Selected]  (shown when >= 1 parked row selected; disabled for Viewer)    |
|                                                                                   |
|  +--+----------+--------+------------+------------+---------+------+------+------+-------+----------+--------+------+-----------+--------+
|  |[ ]| Agency  | Batch  | Claim Date | Agent Name | Bond    | Comm | Comm | Grant| Reg   | Bank     | Comm   | VAT  | Status    |        |
|  |   | Name    | ID     | DD/MM/YYYY | & Surname  | Amount  | Type | %    | Date | Date  |          | Amount |      |           |        |
|  +--+----------+--------+------------+------------+---------+------+------+------+-------+----------+--------+------+-----------+--------+
|  |[ ]| NorthStar|       | 05/01/2026 | A. van Wyk | R 1 5.. | Bond | 0.9% |15/11 | 02/01 | Nedbank  | R 14,..| R 2,.| Parked  |[Unpark]|
|  |[ ]| ABC     |        | 08/01/2026 | T. Mokoena | R 3 0.. | Reg  | 0.9% |18/11 | 05/01 | FNB      | R 28,..| R 4,.| Parked  |[Unpark]|
|  | ...                                                                         ...                                                    |
|  +-----------------------------------------------------------------------...------+
|  (Unpark button disabled and greyed out for Viewer role)                          |
|                                                                                   |
|  ── ERROR STATE (inline, shown when API call fails) ───────────────────────────── |
|  [!] Could not complete the action. [error message from API]  [Dismiss]           |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

## Elements

| Element | Type | Description |
|---------|------|-------------|
| MortgageMax Logo | Image | Brand logo in nav bar |
| Nav links | Nav links | Dashboard, Payment Management (active), Payments Made |
| Reset Demo button | Button | Admin only; triggers screen-8 modal |
| Claim Date filter | Text input | DD/MM/YYYY format; passed as ClaimDate query param |
| Agency Name filter | Dropdown | Options derived from API response values |
| Status filter | Dropdown | Options derived from API response values (not hardcoded) |
| Apply Filters button | Button | Submits filter values; triggers GET /v1/payments with query params |
| Park Selected button | Button | Shown when >= 1 Main Grid row is checked; disabled for Viewer; triggers screen-4 bulk park modal |
| Initiate Payment button | Button | Always visible; disabled for Viewer; triggers screen-6 confirmation modal |
| Main Grid | Data table | Payments with status = ready; 14 columns + checkbox + Park button per row |
| Main Grid checkbox | Checkbox | Per-row multi-select; header checkbox for select-all |
| Park button (per row) | Button | Admin only (disabled for Viewer); triggers screen-4 single park modal for that row |
| Parked Grid | Data table | Payments with status = parked; same 14 columns + checkbox + Unpark button per row |
| Parked Grid checkbox | Checkbox | Per-row multi-select; header checkbox for select-all |
| Unpark Selected button | Button | Shown when >= 1 Parked Grid row is checked; disabled for Viewer; triggers screen-5 bulk unpark modal |
| Unpark button (per row) | Button | Admin only (disabled for Viewer); triggers screen-5 single unpark modal for that row |
| Inline error message | Alert | Displayed when park/unpark/initiate API call fails; grids remain unchanged |

## Grid Columns

Both Main Grid and Parked Grid share identical columns:

| Column | Source Field | Notes |
|--------|-------------|-------|
| (checkbox) | — | Multi-select; not a data column |
| Agency Name | AgencyName | Text |
| Batch ID | BatchId | Blank/null for unbatched payments |
| Claim Date | ClaimDate | DD/MM/YYYY format |
| Agent Name & Surname | AgentName + AgentSurname | Concatenated display |
| Bond Amount | BondAmount | R x xxx,xx format |
| Commission Type | CommissionType | Text; values from API |
| Commission % | CommissionAmount / BondAmount | Calculated: CommissionAmount ÷ BondAmount, displayed as "x.xxx%" |
| Grant Date | GrantDate | DD/MM/YYYY format |
| Registration Date | RegistrationDate | DD/MM/YYYY format |
| Bank | Bank | Text |
| Commission Amount | CommissionAmount | R x xxx,xx format |
| VAT | VAT | R x xxx,xx format |
| Status | Status | Text; values from API |
| Action button | — | Park (Main Grid) or Unpark (Parked Grid); disabled for Viewer |

## User Actions

- **Enter filter values and click Apply Filters:** Re-fetches GET /v1/payments with ClaimDate, AgencyName, Status query params; Main Grid updates.
- **Check row checkbox(es) in Main Grid:** Reveals "Park Selected" button with count; unchecking all hides it.
- **Click Park (single row):** Opens park confirmation modal (screen-4, single variant) for that payment.
- **Click Park Selected:** Opens park confirmation modal (screen-4, bulk variant) with count and combined total.
- **Check row checkbox(es) in Parked Grid:** Reveals "Unpark Selected" button.
- **Click Unpark (single row):** Opens unpark confirmation modal (screen-5, single variant).
- **Click Unpark Selected:** Opens unpark confirmation modal (screen-5, bulk variant).
- **Click Initiate Payment:** Opens initiate confirmation modal (screen-6) summarising count and total of all visible Main Grid payments.
- **Click Reset Demo (Admin only):** Opens reset demo modal (screen-8).

## Navigation

- **From:** Top nav from any screen; Screen 1 agency row click (arrives pre-filtered to agency).
- **To:** Screen 1 (Dashboard) via nav; Screen 3 (Payments Made) via "View Invoice" in success modal (screen-7); park/unpark/initiate confirmation modals; Reset Demo modal.

## Role Differences

| Element | Admin | Viewer |
|---------|-------|--------|
| Park button | Enabled | Rendered, visually disabled (greyed out) |
| Unpark button | Enabled | Rendered, visually disabled (greyed out) |
| Park Selected button | Enabled | Rendered, visually disabled (greyed out) |
| Unpark Selected button | Enabled | Rendered, visually disabled (greyed out) |
| Initiate Payment button | Enabled | Rendered, visually disabled (greyed out) |
| Reset Demo button | Shown | Hidden |
| Payments Made nav link | Shown | Hidden/disabled |
