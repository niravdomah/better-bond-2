# Feature: BetterBond Commission Payments POC

## Problem Statement

BetterBond staff currently process commission payments to real-estate agencies manually, resulting in errors and delays. This system provides a web-based frontend that automates the commission payment workflow — enabling both BetterBond internal staff and real-estate agencies to view payment status, park or unpark individual or bulk payments, initiate payment batches, and download generated invoices — through three dedicated screens: a Dashboard, a Payment Management screen, and a Payments Made screen.

## User Roles

| Role | Description | Key Permissions |
|------|-------------|-----------------|
| Admin | BetterBond internal staff or agency user with full operational access | Access to all three screens; can park/unpark payments (single and bulk); can initiate payment batches; can download invoices; can trigger Reset Demo |
| Viewer | Read-only user (BetterBond staff or agency representative) | Access to Screen 1 (Dashboard) and Screen 2 (Payment Management) in read-only mode; action buttons (Park, Unpark, Initiate Payment) are shown but disabled (greyed out); no access to Screen 3 (Payments Made) |

## Functional Requirements

### Authentication

- **R1:** The application integrates with an external authentication provider (SSO/OAuth). The frontend must handle token/session management from the external provider; no custom login page is built.
- **R2:** All authenticated API requests include the token supplied by the external auth provider. Unauthenticated requests receive a 401 response and the user is redirected to the external auth provider's login flow.
- **R3:** The identity of the authenticated user (from the external auth provider) is used to populate the `LastChangedUser` header on all mutating API calls (park, unpark, initiate payment batch).

### Navigation

- **R4:** A persistent top-level navigation bar is displayed on all pages, providing links to Screen 1 (Dashboard), Screen 2 (Payment Management), and Screen 3 (Payments Made).
- **R5:** For Viewer role users, the Screen 3 (Payments Made) navigation link is hidden or disabled; navigating directly to the Screen 3 URL redirects viewers to Screen 1.

### Screen 1: Dashboard

- **R6:** On initial load, the Dashboard displays aggregate data across all agencies by calling `GET /v1/payments/dashboard` with no agency filter.
- **R7:** The Dashboard displays the following chart components, each sourced from the `PaymentsDashboardRead` response:
  - Payments Ready for Payment bar chart: payment count split by CommissionType, sourced from `PaymentStatusReport` items where status represents "ready" payments (not parked).
  - Parked Payments bar chart: payment count split by CommissionType, sourced from `PaymentStatusReport` items where status represents parked payments.
  - Total Value Ready for Payment: sum of `TotalPaymentAmount` for ready payments from `PaymentStatusReport`.
  - Total Value of Parked Payments: sum of `TotalPaymentAmount` for parked payments from `PaymentStatusReport`.
  - Parked Payments Aging Report: bar or grouped chart using `ParkedPaymentsAgingReport` items, showing `PaymentCount` per `Range` (e.g., "1-3", "4-7", ">7 Days").
  - Total Payment Count in Last 14 Days: displays `TotalPaymentCountInLast14Days` as a numeric count.
- **R8:** The Dashboard displays an Agency Summary grid with one row per agency, sourced from `PaymentsByAgency` in the dashboard response. Columns: Agency Name, Number of Payments (ready, not parked), Total Commission Amount (`TotalCommissionCount`), VAT (`Vat`).
- **R9:** Each row in the Agency Summary grid has a clickable action (button or row click) that navigates to Screen 2 pre-filtered to that agency.
- **R10:** When an agency row is clicked, the Dashboard re-fetches `GET /v1/payments/dashboard` with the selected agency passed as a filter parameter, and all chart components update to reflect the selected agency's data.
- **R11:** When an API call to the dashboard endpoint fails, the user sees an error message describing the failure with a "Retry" option.

### Screen 2: Payment Management

- **R12:** Screen 2 displays two grids for the selected agency: a Main Grid (payments ready for processing) and a Parked Grid (parked payments). Both grids share identical columns (see R13).
- **R13:** Both grids display the following columns: Agency Name, Batch ID (blank/null for unbatched payments), Claim Date, Agent Name & Surname, Bond Amount, Commission Type, Commission % (calculated as `CommissionAmount / BondAmount`, displayed as a percentage, e.g., "0.945%"), Grant Date, Registration Date, Bank, Commission Amount, VAT, Status.
- **R14:** Screen 2 can be navigated to directly from the top nav (no agency pre-selected), in which case both grids display payments across all agencies. When arrived at via an agency row click from Screen 1, both grids are pre-filtered to that agency.
- **R15:** A search/filter bar above the Main Grid allows filtering payments by Claim Date, Agency Name, and Status. Submitting the filter triggers a server-side re-fetch of `GET /v1/payments` with the selected filter values passed as query parameters (`ClaimDate`, `AgencyName`, `Status`).
- **R16:** Status and CommissionType filter options are derived dynamically from values returned by the API — they are not hardcoded.
- **R17:** Each row in the Main Grid has a "Park" button (disabled for Viewer role). Clicking it shows a confirmation modal with the message "Are you sure you want to park this payment?" and displays the Agent Name, Claim Date, and Commission Amount of the payment. Confirming calls `PUT /v1/payments/park` with the single payment ID and moves the payment from the Main Grid to the Parked Grid.
- **R18:** The Main Grid supports multi-select via checkboxes. A "Park Selected" button (disabled for Viewer role) is shown when one or more payments are selected. Clicking it shows a confirmation modal with the count of selected payments and their combined total commission amount. Confirming calls `PUT /v1/payments/park` with all selected payment IDs and moves those payments to the Parked Grid.
- **R19:** Each row in the Parked Grid has an "Unpark" button (disabled for Viewer role). Clicking it shows a confirmation modal with the payment details (Agent Name, Claim Date, Commission Amount). Confirming calls `PUT /v1/payments/unpark` with the single payment ID and moves the payment from the Parked Grid back to the Main Grid.
- **R20:** The Parked Grid supports multi-select via checkboxes. An "Unpark Selected" button (disabled for Viewer role) is shown when one or more parked payments are selected. Clicking it shows a confirmation modal with the count of payments and combined total. Confirming calls `PUT /v1/payments/unpark` with all selected payment IDs and returns those payments to the Main Grid.
- **R21:** An "Initiate Payment" button (disabled for Viewer role) is displayed on Screen 2. Clicking it shows a confirmation modal summarising the count and total value of all payments currently in the Main Grid (as filtered/visible). Confirming calls `POST /v1/payment-batches` with the IDs of all payments in the current Main Grid view.
- **R22:** After a successful Initiate Payment call, the processed payments are removed from the Main Grid. A success modal is displayed with a "View Invoice" button that navigates to Screen 3.
- **R23:** When any mutating API call (park, unpark, initiate) fails, the user sees an error message describing the failure; the grids are not changed.

### Screen 3: Payments Made

- **R24:** Screen 3 is accessible to Admin users only. Viewer users cannot see Screen 3 (per R5).
- **R25:** Screen 3 displays a grid of completed payment batches, sourced from `GET /v1/payment-batches`. Columns: Agency Name, Number of Payments (`PaymentCount`), Total Commission Amount (`TotalCommissionAmount`), VAT (`TotalVat`), Invoice (a download link/button per row).
- **R26:** A search/filter bar allows filtering by Agency Name and Batch Reference. Submitting the filter triggers a server-side re-fetch of `GET /v1/payment-batches` with `AgencyName` and `Reference` query parameters.
- **R27:** Clicking the invoice download link for a batch calls `POST /v1/payment-batches/{Id}/download-invoice-pdf`, receives the PDF binary response, and triggers a browser download or opens the PDF in a new browser tab.
- **R28:** When Screen 3 is navigated to after a successful Initiate Payment (via the "View Invoice" button from the success modal), the newly created batch is visible in the grid immediately (the batch creation is synchronous).
- **R29:** When an API call on Screen 3 fails, the user sees an error message with a "Retry" option.

### Demo Administration

- **R30:** An "Reset Demo" button, visible and accessible to Admin users only, calls `POST /demo/reset-demo`. After a successful call the user sees a confirmation message and the application data is refreshed to its demo state.
- **R31:** The Reset Demo button is not visible to Viewer role users.

### General / Cross-Cutting

- **R32:** All currency values are formatted using en-ZA locale: ZAR (R), space as thousands separator, comma as decimal separator (e.g., "R 1 234 567,89").
- **R33:** All date values are displayed in DD/MM/YYYY format (en-ZA locale).
- **R34:** The MortgageMax brand logo is displayed in the application header/nav bar.

## Business Rules

- **BR1:** Only Admin role users can access Screen 3 (Payments Made). Viewer users who navigate directly to the Screen 3 URL are redirected to Screen 1.
- **BR2:** On Screen 2, action buttons (Park, Unpark, Park Selected, Unpark Selected, Initiate Payment) are rendered in the DOM for Viewer users but are visually disabled (greyed out) and cannot be activated.
- **BR3:** The "Initiate Payment" action processes ALL payments currently visible in the Main Grid — not only selected rows. If the grid is filtered, only the filtered/visible payments are included in the batch.
- **BR4:** One Initiate Payment action produces exactly one payment batch (and one invoice) per agency per invocation.
- **BR5:** Commission % is a calculated display value: `CommissionAmount / BondAmount`, formatted as a percentage (e.g., "0.945%"). It is not stored or returned by the API.
- **BR6:** The `LastChangedUser` header sent on all mutating API calls (park, unpark, create batch) is derived from the identity of the authenticated user provided by the external auth provider — not entered manually.
- **BR7:** Payment Status and Commission Type values are not hardcoded in the frontend. Filter options and display values are derived dynamically from the values returned by the API.
- **BR8:** Payments with no assigned batch display a blank/null value in the Batch ID column — not zero or a placeholder.
- **BR9:** After a successful Initiate Payment call, the system treats batch creation as synchronous. The processed payments are immediately removed from the Main Grid and the new batch is immediately visible on Screen 3 — no polling or delayed refresh is required.
- **BR10:** The Reset Demo action is available to Admin users only. It resets the application's demo dataset to its initial state.
- **BR11:** All ZAR amounts are displayed and formatted in South African Rand (ZAR, "R") only. Multi-currency is not supported.

## Data Model

### Entities (UI-observable fields from API)

| Entity | Key Fields | Relationships |
|--------|-----------|---------------|
| Payment | Id, Reference, AgencyName, ClaimDate, AgentName, AgentSurname, BondAmount, CommissionType, CommissionAmount (+ calculated Commission%), GrantDate, RegistrationDate, Bank, VAT, Status, BatchId, LastChangedUser, LastChangedDate | Belongs to an agency (by name); optionally belongs to a PaymentBatch (BatchId) |
| PaymentBatch | Id, CreatedDate, Status, Reference, AgencyName, PaymentCount, TotalCommissionAmount, TotalVat, LastChangedUser | Groups one or more Payments for one agency |
| PaymentsDashboard | PaymentStatusReport[], ParkedPaymentsAgingReport[], TotalPaymentCountInLast14Days, PaymentsByAgency[] | Aggregate view; no direct entity relationships — data is derived from Payments |
| PaymentStatusReportItem | Status, PaymentCount, TotalPaymentAmount, CommissionType, AgencyName | Part of PaymentsDashboard |
| ParkedPaymentsAgingReportItem | Range, AgencyName, PaymentCount | Part of PaymentsDashboard |
| PaymentsByAgencyReportItem | AgencyName, PaymentCount, TotalCommissionCount, Vat | Part of PaymentsDashboard; drives the Agency Summary grid on Screen 1 |

## Key Workflows

### Workflow 1: Dashboard — Agency Filter

1. User opens Screen 1; frontend calls `GET /v1/payments/dashboard` with no agency filter; all charts and Agency Summary grid populate with aggregate data.
2. User clicks a row in the Agency Summary grid.
3. Frontend re-fetches `GET /v1/payments/dashboard` with the selected agency name as a filter parameter.
4. All chart components and aggregate values update to reflect data for the selected agency.
5. User is navigated to Screen 2 pre-filtered to that agency.

### Workflow 2: Park Payment (Single)

1. User (Admin) clicks the "Park" button on a payment row in the Main Grid on Screen 2.
2. A confirmation modal appears showing: "Are you sure you want to park this payment?", Agent Name, Claim Date, and Commission Amount.
3. User clicks "Confirm".
4. Frontend calls `PUT /v1/payments/park` with `{ PaymentIds: [id] }` and `LastChangedUser` header.
5. On success: the payment row moves from the Main Grid to the Parked Grid.
6. On failure: an error message is shown; the grids remain unchanged.

### Workflow 3: Park Payment (Bulk)

1. User (Admin) selects multiple payments in the Main Grid using checkboxes.
2. User clicks "Park Selected".
3. A confirmation modal appears showing the count of selected payments and their combined total commission amount.
4. User clicks "Confirm".
5. Frontend calls `PUT /v1/payments/park` with `{ PaymentIds: [...ids] }` and `LastChangedUser` header.
6. On success: the selected payments move from the Main Grid to the Parked Grid.
7. On failure: an error message is shown; the grids remain unchanged.

### Workflow 4: Unpark Payment (Single and Bulk)

1. User (Admin) clicks "Unpark" (single) or selects payments and clicks "Unpark Selected" (bulk) in the Parked Grid.
2. A confirmation modal appears with details of the payments being unparked.
3. User clicks "Confirm".
4. Frontend calls `PUT /v1/payments/unpark` with the relevant `PaymentIds` and `LastChangedUser` header.
5. On success: the payments move from the Parked Grid back to the Main Grid.
6. On failure: an error message is shown; the grids remain unchanged.

### Workflow 5: Initiate Payment (Create Batch)

1. User (Admin) clicks "Initiate Payment" on Screen 2.
2. A confirmation modal appears summarising the count and total value of all payments currently visible in the Main Grid.
3. User clicks "Confirm".
4. Frontend calls `POST /v1/payment-batches` with `{ PaymentIds: [...all visible main grid ids] }` and `LastChangedUser` header.
5. On success: processed payments are removed from the Main Grid; a success modal appears with a "View Invoice" button.
6. User clicks "View Invoice" — navigates to Screen 3 where the new batch is immediately visible.
7. On failure: an error message is shown; the Main Grid is unchanged.

### Workflow 6: Download Invoice

1. User (Admin) navigates to Screen 3 (Payments Made).
2. User clicks the invoice download link for a batch row.
3. Frontend calls `POST /v1/payment-batches/{Id}/download-invoice-pdf`.
4. The returned PDF binary is downloaded to the user's browser or opened in a new tab.
5. On failure: an error message is shown.

### Workflow 7: Search / Filter Payments (Screen 2)

1. User enters values in the search/filter bar fields (Claim Date, Agency Name, Status).
2. User submits the filter (clicks a "Search" or "Apply" button).
3. Frontend calls `GET /v1/payments` with the entered values as query parameters.
4. The Main Grid updates with the filtered results.

### Workflow 8: Reset Demo

1. Admin user clicks the "Reset Demo" button.
2. A confirmation prompt is shown.
3. User confirms.
4. Frontend calls `POST /demo/reset-demo`.
5. On success: a confirmation message is shown and all screens refresh to reflect the reset data.

## Non-Functional Requirements

- **NFR1:** Layout is responsive — the application must be usable on desktop, tablet, and mobile screen sizes.
- **NFR2:** Dates are displayed in DD/MM/YYYY format throughout the application (en-ZA locale).
- **NFR3:** Currency values are formatted using en-ZA locale conventions: "R 1 234 567,89" (space as thousands separator, comma as decimal separator, "R" prefix).
- **NFR4:** The application supports modern browsers: Chrome, Firefox, Edge, and Safari (latest stable versions).
- **NFR5:** Basic keyboard navigation and semantic HTML are implemented (WCAG AA compliance is not required for this POC, but heading hierarchy, button roles, label associations, and tab order are expected).
- **NFR6:** The application operates in light mode. The MortgageMax brand logo from `documentation/morgagemaxlogo.png` is incorporated in the navigation/header.
- **NFR7:** All API calls are made through the shared API client (`web/src/lib/api/client.ts`). Direct `fetch()` calls in components are not permitted.
- **NFR8:** The backend API base URL is `http://localhost:8042`. All API paths are relative to this base.

## Out of Scope

- Login page — authentication is handled entirely by an external SSO/OAuth provider; no custom login UI is built.
- Email notifications to agencies.
- Editing or deleting individual payment records.
- Creating new payment records from the frontend.
- Multi-currency support — ZAR only.
- CSV or Excel export.
- Full WCAG AA accessibility audit — only basic keyboard nav and semantic HTML are required for this POC.
- Agency profile management or agency data editing.

## Source Traceability

| ID | Source | Reference |
|----|--------|-----------|
| R1 | User input | Clarifying question: "Is external auth integration in scope?" — Answer: Yes, SSO/OAuth token/session handling needed, no login page built from scratch. |
| R2 | `documentation/Api Definition.yaml` | `401` responses defined on all endpoints; external auth implied |
| R3 | User input | Clarifying question: "How is the LastChangedUser header value derived?" — Answer: From authenticated user context provided by the external auth provider. |
| R4 | User input | Clarifying question: "Is navigation a top-level nav bar?" — Answer: Yes, persistent nav bar with all 3 screens. |
| R5 | User input | Clarifying question: "Can viewers access Screen 3?" — Answer: No. Screen 3 is Admin only; Screen 3 nav link hidden/disabled for Viewer. |
| R6 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 1: Dashboard Components — "Each visual component should update dynamically when an agency is selected" |
| R7 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 1: Dashboard Components (all chart items); `documentation/Api Definition.yaml` — `PaymentsDashboardRead` schema |
| R8 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 1: Dashboard Grid (Agency Summary) — Grid Fields |
| R9 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 1: Dashboard Grid — "Each record is clickable (button on row), navigates to Screen 2 for that specific agency" |
| R10 | User input | Clarifying question: "How does agency selection filtering work?" — Answer: Server-side re-fetch of dashboard API with agency filter parameter. |
| R11 | User input | Clarifying question: error handling pattern — Answer: Show error message with Retry option. |
| R12 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 2: Main Grid and Parked Grid sections |
| R13 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 2: Columns list; User input — Commission % calculated field; `documentation/Api Definition.yaml` — `PaymentRead` schema |
| R14 | User input | Clarifying question: "Can Screen 2 show all-agency payments when navigated directly?" — Answer: Yes; pre-filtered when arrived from Screen 1. |
| R15 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 2: "Search Bar: Filter by Claim Date, Agency Name, Status"; `documentation/Api Definition.yaml` — `GET /v1/payments` query parameters |
| R16 | User input | Clarifying question: "Are payment statuses and commission types hardcoded?" — Answer: No, use values from the API dynamically. |
| R17 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 2: Single Payment Parking — modal details and confirmation flow |
| R18 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 2: Bulk Parking — checkboxes, Park Selected modal |
| R19 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 2: Parked Grid — "Unpark individual" flow |
| R20 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 2: Parked Grid — "Unpark multiple payments" flow |
| R21 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 2: Initiate Payment — "Button initiates the payment process for all payments in the Main Grid"; `documentation/Api Definition.yaml` — `POST /v1/payment-batches` |
| R22 | User input | Clarifying question: "What happens post-initiation?" — Answer: Show success modal with "View Invoice" button navigating to Screen 3. |
| R23 | User input | Clarifying question: error handling pattern for mutating operations. |
| R24 | User input | Clarifying question: "Can Viewer access Screen 3?" — Answer: No, Admin only. |
| R25 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 3: Fields — Agency Name, Number of Payments, Total Commission Amount, VAT, Invoice Link; `documentation/Api Definition.yaml` — `PaymentBatchRead` schema |
| R26 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 3: "Search bar for filtering by Agency Name or Batch ID"; `documentation/Api Definition.yaml` — `GET /v1/payment-batches` query parameters |
| R27 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 3: "Clickable invoice link to open/download invoice"; User input — "the invoice PDF is downloaded from the API (POST /v1/payment-batches/{Id}/download-invoice-pdf)"; `documentation/Api Definition.yaml` — `PaymentBatchDownloadInvoicePdf` |
| R28 | User input | Clarifying question: "What happens after initiation?" — Answer: Optimistic/synchronous, batch immediately visible on Screen 3. |
| R29 | User input | Error handling pattern for Screen 3. |
| R30 | User input | Clarifying question: "Is Reset Demo in scope?" — Answer: Yes, Admin only, calls `POST /demo/reset-demo`; `documentation/Api Definition.yaml` — `/demo/reset-demo` endpoint |
| R31 | User input | Clarifying question: "Is Reset Demo Admin only?" — Answer: Yes. |
| R32 | User input | Clarifying question: "What locale should be used?" — Answer: en-ZA throughout, R 1 234 567,89 currency formatting. |
| R33 | User input | Clarifying question: "What locale for dates?" — Answer: en-ZA, DD/MM/YYYY. |
| R34 | `generated-docs/context/intake-manifest.json` | `context.stylingNotes` — "incorporate provided MortgageMax brand logo" |
| BR1 | User input | Clarifying question: "Can Viewer access Screen 3?" — Answer: No; redirect to Screen 1. |
| BR2 | User input | Clarifying question: "How should action buttons appear for Viewer on Screen 2?" — Answer: Shown but disabled (greyed out). |
| BR3 | User input | Clarifying question: "Does Initiate Payment process all grid items or only selected?" — Answer: All payments currently in the Main Grid (as filtered). |
| BR4 | `documentation/BetterBond-Commission-Payments-POC-002.md` | Screen 2: Invoice Generation — "Each invoice... grouped by that specific agency"; User input — "One initiation = one invoice/batch per agency" |
| BR5 | User input | Clarifying question: "How is Commission % calculated?" — Answer: CommissionAmount / BondAmount, displayed as percentage. Not an API field. |
| BR6 | User input | Clarifying question: "How is LastChangedUser header populated?" — Answer: Derived from authenticated user context from external auth provider. |
| BR7 | User input | Clarifying question: "Are statuses and commission types hardcoded?" — Answer: No, derived from API response values. |
| BR8 | User input | Clarifying question: "What shows in Batch ID column for unbatched payments?" — Answer: Blank/null. |
| BR9 | User input | Clarifying question: "After initiation, do payments appear on Screen 3 immediately?" — Answer: Yes, synchronous batch creation. |
| BR10 | User input | Clarifying question: "Is Reset Demo Admin only?" — Answer: Yes. |
| BR11 | User input | Clarifying question: "What currency?" — Answer: ZAR only; multi-currency is out of scope. |
