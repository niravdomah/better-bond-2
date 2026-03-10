# Feature: BetterBond Commission Payments POC-002

## Summary

A frontend portal for MortgageMax administrators and viewers to manage, park, unpark, initiate, and download invoices for bond origination commission payments. The application connects to a live REST API at http://localhost:8042 and enforces RBAC (Admin vs. Viewer roles).

## Epics

1. **Epic 1: Application Shell and Navigation** - Persistent navigation bar with MortgageMax brand logo, route structure for all three screens, SSO/OAuth token/session authentication with 401 redirect, RBAC enforcement (Viewer redirect from Screen 3 to Screen 1), shared ZAR currency and DD/MM/YYYY date formatting utilities, and API client base URL configured to http://localhost:8042. | Status: Pending | Dir: `epic-1-application-shell-and-navigation/`

2. **Epic 2: Dashboard (Screen 1)** - Dashboard as the home page sourced from GET /v1/payments/dashboard. Bar charts for ready/parked payments by CommissionType, KPI value cards for total ready/parked amounts, Parked Payments Aging Report chart, Total Payment Count in Last 14 Days metric, Agency Summary grid with per-agency rows. Agency row click re-fetches with agency filter and navigates to Screen 2 pre-filtered. Error state with Retry. | Status: Pending | Dir: `epic-2-dashboard/`

3. **Epic 3: Payment Management (Screen 2)** - Payment Management screen sourced from GET /v1/payments. Main Grid (ready payments) and Parked Grid (parked payments). Filter bar (Claim Date, Agency Name, Status — server-side re-fetch). Park and unpark flows (single and bulk) with confirmation modals. Initiate Payment flow with confirmation modal, POST /v1/payment-batches, success modal with "View Invoice" navigation to Screen 3. RBAC: action buttons shown but disabled for Viewer. LastChangedUser header on all mutating calls. | Status: Pending | Dir: `epic-3-payment-management/`

4. **Epic 4: Payments Made and Invoice Download (Screen 3)** - Payments Made screen (Admin only) sourced from GET /v1/payment-batches. Payment batches grid. Filter bar (Agency Name, Batch Reference). Invoice PDF download via POST /v1/payment-batches/{Id}/download-invoice-pdf. Error states with Retry. Reset Demo button (Admin only) with confirmation prompt and full-app data refresh on success. | Status: Pending | Dir: `epic-4-payments-made-and-invoice-download/`

## Epic Dependencies

- **Epic 1: Application Shell and Navigation** — No dependencies — must be first. Provides the foundation all other epics build upon (nav, auth, RBAC, API client, shared utilities). Cannot be parallelised with any other epic.
- **Epic 2: Dashboard** — Depends on Epic 1. Can begin immediately after Epic 1 completes. Cannot parallel with Epic 3 or 4 as they depend on it for agency filter navigation context.
- **Epic 3: Payment Management** — Depends on Epics 1 and 2. Requires Epic 2 because the Dashboard's agency row click navigates to Screen 2 pre-filtered (integration point). Cannot parallel with Epic 4 as Epic 4 depends on it.
- **Epic 4: Payments Made and Invoice Download** — Depends on Epics 1 and 3. Requires Epic 3 because the Initiate Payment success modal's "View Invoice" link navigates to Screen 3. Final epic in the chain.

## Execution Order

Epic 1 → Epic 2 → Epic 3 → Epic 4 (fully sequential — each epic depends on the previous).

## Known Flags

- **Missing query parameters in OpenAPI spec:** `GET /v1/payments/dashboard` does not define query parameters in the API spec, but the requirements (R10) call for agency filtering. The frontend will pass `AgencyName` as a query parameter. This should be confirmed with the backend team or spec should be updated.
