# Screen: Payments Made

## Purpose
Displays completed payment batches for Admin users. Allows filtering by agency name or batch reference, and provides a per-row invoice PDF download action.

## Access
Admin role only. Viewer users cannot access this screen — they are redirected to Screen 1 (Dashboard) if they navigate directly to the URL.

## Wireframe

```
+-----------------------------------------------------------------------------------+
|  [MortgageMax Logo]   Dashboard  Payment Management  Payments Made   [Reset Demo] |
|  (logo image, left)   (nav link)    (nav link)          (nav link, active)        |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  Payments Made                                                                    |
|  ─────────────────────────────────────────────────────────────────────────────── |
|                                                                                   |
|  Filter Batches                                                                   |
|  +---------------------------------------------------+                           |
|  | [Agency Name v]   [Batch Reference...]            | [Apply Filters]            |
|  +---------------------------------------------------+                           |
|  (Agency Name: dropdown or free-text; passed as AgencyName query param)           |
|  (Batch Reference: text input; passed as Reference query param)                   |
|                                                                                   |
|  ── Payment Batches ──────────────────────────────────────────────────────────── |
|                                                                                   |
|  +-----------------------------------------------------------------------+       |
|  | Agency Name         | # Payments | Total Commission   | VAT          | Invoice |
|  |---------------------|------------|--------------------|--------------+---------|
|  | ABC Realty          |     12     | R 45 678,00        | R 6 851,70   | [PDF]   |
|  | Platinum Properties |      8     | R 32 100,00        | R 4 815,00   | [PDF]   |
|  | Coastal Homes       |      5     | R 18 900,00        | R 2 835,00   | [PDF]   |
|  | NorthStar Estates   |      7     | R 27 450,00        | R 4 117,50   | [PDF]   |
|  | Sun Valley Realty   |      3     | R 11 200,00        | R 1 680,00   | [PDF]   |
|  +-----------------------------------------------------------------------+       |
|  (currency: R x xxx,xx en-ZA format)                                             |
|  ([PDF] = clickable button; triggers POST /v1/payment-batches/{Id}/download-...) |
|  (newly created batches appear immediately at top after Initiate Payment)         |
|                                                                                   |
|  ── ERROR STATE (shown when API call fails) ───────────────────────────────────── |
|  [!] Failed to load payment batches.                                              |
|      Unable to reach the server. Please check your connection and try again.      |
|      [Retry]                                                                      |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

## Elements

| Element | Type | Description |
|---------|------|-------------|
| MortgageMax Logo | Image | Brand logo in nav bar |
| Nav links | Nav links | Dashboard, Payment Management, Payments Made (active) |
| Reset Demo button | Button | Admin only; triggers screen-8 modal |
| Agency Name filter | Dropdown / text input | Passed as AgencyName query param to GET /v1/payment-batches |
| Batch Reference filter | Text input | Passed as Reference query param to GET /v1/payment-batches |
| Apply Filters button | Button | Triggers re-fetch of GET /v1/payment-batches with filter params |
| Payment Batches grid | Data table | One row per PaymentBatchRead; columns listed below |
| [PDF] invoice button | Button / link | Per row; triggers POST /v1/payment-batches/{Id}/download-invoice-pdf; result downloaded or opened in new tab |
| Error state | Alert + Button | Shown when GET /v1/payment-batches fails; includes Retry button |

## Grid Columns

| Column | Source Field | Notes |
|--------|-------------|-------|
| Agency Name | AgencyName | Text |
| # Payments | PaymentCount | Integer count |
| Total Commission Amount | TotalCommissionAmount | R x xxx,xx format |
| VAT | TotalVat | R x xxx,xx format |
| Invoice | — | [PDF] download button per row; calls POST /v1/payment-batches/{Id}/download-invoice-pdf |

## User Actions

- **Enter filter values and click Apply Filters:** Re-fetches GET /v1/payment-batches with AgencyName and Reference query params; grid updates.
- **Click [PDF] invoice button:** Calls POST /v1/payment-batches/{Id}/download-invoice-pdf; browser downloads or opens PDF.
- **Click Retry (error state):** Re-fetches GET /v1/payment-batches.
- **Click Reset Demo:** Opens Reset Demo modal (screen-8).
- **Click nav links:** Navigate to the respective screen.

## Navigation

- **From:** Screen 2 via "View Invoice" button in Initiate Payment success modal (screen-7); top nav.
- **To:** Screen 1 (Dashboard) via nav; Screen 2 (Payment Management) via nav; Reset Demo modal (screen-8).

## Data Source

| Data | API Call | Field |
|------|----------|-------|
| Payment batches list | GET /v1/payment-batches | PaymentBatchReadList.PaymentBatchList |
| Invoice download | POST /v1/payment-batches/{Id}/download-invoice-pdf | application/octet-stream PDF binary |
