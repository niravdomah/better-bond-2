# Screen: Dashboard

## Purpose
Provides an aggregate overview of commission payment status across all agencies (or a selected agency), including KPI cards, bar charts, and an agency summary grid.

## Wireframe

```
+-----------------------------------------------------------------------------------+
|  [MortgageMax Logo]   Dashboard  Payment Management  Payments Made   [Reset Demo] |
|  (logo image, left)   (nav link)    (nav link)          (nav link)   (Admin only) |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  Dashboard                                  [Agency Filter v]  (all agencies)     |
|  ─────────────────────────────────────────────────────────────────────────────── |
|                                                                                   |
|  +-------------------------------+  +-------------------------------+             |
|  | Payments Ready for Payment    |  | Parked Payments               |             |
|  | ── Bar Chart ──               |  | ── Bar Chart ──               |             |
|  |  ^                            |  |  ^                            |             |
|  | 8|  ████                      |  | 4|       ████                 |             |
|  | 6|  ████  ████                |  | 2|  ████ ████                 |             |
|  | 4|  ████  ████  ████          |  | 1|  ████ ████ ████            |             |
|  |   Type A Type B Type C        |  |   Type A Type B Type C        |             |
|  | (by CommissionType, X-axis)   |  | (by CommissionType, X-axis)   |             |
|  +-------------------------------+  +-------------------------------+             |
|                                                                                   |
|  +-------------------------------+  +-------------------------------+             |
|  | Total Value Ready for Payment |  | Total Value of Parked Payments|             |
|  |                               |  |                               |             |
|  |     R 1 234 567,89            |  |     R 234 567,00              |             |
|  |                               |  |                               |             |
|  +-------------------------------+  +-------------------------------+             |
|                                                                                   |
|  +-------------------------------+  +-------------------------------+             |
|  | Parked Payments Aging Report  |  | Total Payments in Last 14 Days|             |
|  | ── Bar Chart ──               |  |                               |             |
|  |  ^                            |  |              42               |             |
|  | 5|  ████                      |  |                               |             |
|  | 3|  ████  ████                |  |                               |             |
|  | 1|  ████  ████  ████          |  +-------------------------------+             |
|  |  1-3 days 4-7 days >7 days   |                                                |
|  +-------------------------------+                                                |
|                                                                                   |
|  Agency Summary                                                                   |
|  ─────────────────────────────────────────────────────────────────────────────── |
|  +-----------------------------------------------------------------------------+ |
|  | Agency Name         | # Payments | Total Commission    | VAT          |      | |
|  |---------------------|------------|---------------------|--------------|------| |
|  | ABC Realty          |     12     | R 45 678,00         | R 6 851,70   | [->] | |
|  | Platinum Properties |      8     | R 32 100,00         | R 4 815,00   | [->] | |
|  | Coastal Homes       |      5     | R 18 900,00         | R 2 835,00   | [->] | |
|  | NorthStar Estates   |      7     | R 27 450,00         | R 4 117,50   | [->] | |
|  | Sun Valley Realty   |      3     | R 11 200,00         | R 1 680,00   | [->] | |
|  +-----------------------------------------------------------------------------+ |
|                                                                                   |
+-----------------------------------------------------------------------------------+

── ERROR STATE (shown instead of charts/grid when API fails) ──────────────────────
|                                                                                   |
|  [!] Failed to load dashboard data.                                               |
|      Unable to reach the server. Please check your connection and try again.      |
|      [Retry]                                                                      |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

## Elements

| Element | Type | Description |
|---------|------|-------------|
| MortgageMax Logo | Image | Brand logo in top-left of nav bar |
| Dashboard nav link | Nav link | Navigates to Screen 1; active state highlighted |
| Payment Management nav link | Nav link | Navigates to Screen 2 |
| Payments Made nav link | Nav link | Navigates to Screen 3; hidden/disabled for Viewer role |
| Reset Demo button | Button | Admin only; triggers Reset Demo modal (screen-8); not shown to Viewer |
| Agency Filter | Dropdown | Filters all dashboard data to a selected agency; default "All Agencies"; triggers re-fetch of GET /v1/payments/dashboard |
| Payments Ready for Payment chart | Bar chart | Count of ready payments by CommissionType; sourced from PaymentStatusReport |
| Parked Payments chart | Bar chart | Count of parked payments by CommissionType; sourced from PaymentStatusReport |
| Total Value Ready for Payment | KPI card | Sum of TotalPaymentAmount for ready-status items; formatted R x xxx,xx |
| Total Value of Parked Payments | KPI card | Sum of TotalPaymentAmount for parked-status items; formatted R x xxx,xx |
| Parked Payments Aging Report chart | Bar chart | PaymentCount per Range ("1-3", "4-7", ">7 Days") from ParkedPaymentsAgingReport |
| Total Payments in Last 14 Days | KPI card | Displays TotalPaymentCountInLast14Days as a numeric count |
| Agency Summary grid | Data table | One row per agency from PaymentsByAgency; columns: Agency Name, # Payments, Total Commission Amount, VAT |
| Agency row action button [->] | Button | Navigates to Screen 2 pre-filtered to that agency; also re-fetches dashboard with agency filter |
| Error state | Alert + Button | Shown when API call fails; includes error message and Retry button |

## User Actions

- **Select agency from filter dropdown:** Re-fetches GET /v1/payments/dashboard with selected agency; all charts and KPI cards update.
- **Click agency row [->] button:** Re-fetches dashboard with agency filter, then navigates to Screen 2 pre-filtered to that agency.
- **Click Retry (error state):** Re-fetches GET /v1/payments/dashboard.
- **Click Reset Demo (Admin only):** Opens Reset Demo confirmation modal (screen-8).
- **Click nav links:** Navigate to the respective screen.

## Navigation

- **From:** Any screen via top nav; default entry point on app load.
- **To:** Screen 2 (Payment Management) via agency row click or nav link; Screen 3 (Payments Made) via nav link (Admin only); Reset Demo modal (screen-8) via button.

## Data Sources

| Data | API Call | Field |
|------|----------|-------|
| Charts & KPI cards | GET /v1/payments/dashboard | PaymentsDashboardRead |
| Payments Ready chart | PaymentsDashboardRead.PaymentStatusReport | Items where status = ready, grouped by CommissionType |
| Parked Payments chart | PaymentsDashboardRead.PaymentStatusReport | Items where status = parked, grouped by CommissionType |
| Total Value Ready | PaymentsDashboardRead.PaymentStatusReport | Sum of TotalPaymentAmount (ready items) |
| Total Value Parked | PaymentsDashboardRead.PaymentStatusReport | Sum of TotalPaymentAmount (parked items) |
| Aging Report chart | PaymentsDashboardRead.ParkedPaymentsAgingReport | PaymentCount per Range |
| Total 14-day count | PaymentsDashboardRead.TotalPaymentCountInLast14Days | Integer count |
| Agency Summary grid | PaymentsDashboardRead.PaymentsByAgency | AgencyName, PaymentCount, TotalCommissionCount, Vat |
