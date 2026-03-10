# Screen: Park Payment Confirmation Modal

## Purpose
Confirmation dialog displayed before parking one or more payments. Has two variants: Single (triggered by the row-level "Park" button) and Bulk (triggered by "Park Selected" after multi-select).

## Access
Admin role only. Action buttons are disabled for Viewer users so this modal is never triggered for Viewers.

## Wireframe

### Variant A — Single Payment

```
+------------------------------------------------------------------+
|  (backdrop: screen behind is dimmed)                              |
|                                                                   |
|  +------------------------------------------------------------+  |
|  |  Park Payment                                         [X]  |  |
|  |------------------------------------------------------------|  |
|  |                                                            |  |
|  |  Are you sure you want to park this payment?               |  |
|  |                                                            |  |
|  |  Agent:             John Smith                             |  |
|  |  Claim Date:        15/01/2026                             |  |
|  |  Commission Amount: R 11 340,00                            |  |
|  |                                                            |  |
|  |  This payment will be moved to the Parked list.            |  |
|  |                                                            |  |
|  |               [Cancel]    [Confirm Park]                   |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

### Variant B — Bulk Park (multiple payments selected)

```
+------------------------------------------------------------------+
|  (backdrop: screen behind is dimmed)                              |
|                                                                   |
|  +------------------------------------------------------------+  |
|  |  Park Selected Payments                               [X]  |  |
|  |------------------------------------------------------------|  |
|  |                                                            |  |
|  |  Are you sure you want to park these payments?             |  |
|  |                                                            |  |
|  |  Payments selected:    3                                   |  |
|  |  Combined total:       R 34 020,00                         |  |
|  |                                                            |  |
|  |  These payments will be moved to the Parked list.          |  |
|  |                                                            |  |
|  |               [Cancel]    [Confirm Park]                   |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

## Elements

| Element | Type | Description |
|---------|------|-------------|
| Modal backdrop | Overlay | Dims the background screen; clicking outside dismisses (Cancel behaviour) |
| [X] close button | Button | Dismisses modal without action |
| Title | Heading | "Park Payment" (single) or "Park Selected Payments" (bulk) |
| Confirmation text | Text | "Are you sure you want to park this payment?" / "...these payments?" |
| Agent (single only) | Read-only text | AgentName + AgentSurname of the payment |
| Claim Date (single only) | Read-only text | ClaimDate in DD/MM/YYYY format |
| Commission Amount (single only) | Read-only text | CommissionAmount in R x xxx,xx format |
| Payments selected (bulk only) | Read-only text | Count of selected payment IDs |
| Combined total (bulk only) | Read-only text | Sum of CommissionAmount for selected payments; R x xxx,xx format |
| [Cancel] button | Button | Dismisses modal; no API call; no grid changes |
| [Confirm Park] button | Button | Calls PUT /v1/payments/park with PaymentIds; on success payments move to Parked Grid; on failure shows inline error |

## User Actions

- **Click [Cancel] or [X] or outside modal:** Dismisses modal; Main Grid unchanged.
- **Click [Confirm Park]:** Calls PUT /v1/payments/park with { PaymentIds: [id] } (single) or { PaymentIds: [...ids] } (bulk); on success moves payment(s) from Main Grid to Parked Grid and closes modal; on failure shows error message (modal may remain open or close with inline error on Screen 2).

## Navigation

- **From:** Screen 2 Main Grid — single "Park" button or "Park Selected" button.
- **To:** Returns to Screen 2; no navigation change on success (grids update in place).
