# Screen: Unpark Payment Confirmation Modal

## Purpose
Confirmation dialog displayed before unparking one or more payments. Has two variants: Single (triggered by the row-level "Unpark" button in the Parked Grid) and Bulk (triggered by "Unpark Selected" after multi-select in the Parked Grid).

## Access
Admin role only. Action buttons are disabled for Viewer users so this modal is never triggered for Viewers.

## Wireframe

### Variant A — Single Payment

```
+------------------------------------------------------------------+
|  (backdrop: screen behind is dimmed)                              |
|                                                                   |
|  +------------------------------------------------------------+  |
|  |  Unpark Payment                                       [X]  |  |
|  |------------------------------------------------------------|  |
|  |                                                            |  |
|  |  Are you sure you want to unpark this payment?             |  |
|  |                                                            |  |
|  |  Agent:             Andile van Wyk                         |  |
|  |  Claim Date:        05/01/2026                             |  |
|  |  Commission Amount: R 14 175,00                            |  |
|  |                                                            |  |
|  |  This payment will be returned to the ready list.          |  |
|  |                                                            |  |
|  |               [Cancel]    [Confirm Unpark]                 |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

### Variant B — Bulk Unpark (multiple parked payments selected)

```
+------------------------------------------------------------------+
|  (backdrop: screen behind is dimmed)                              |
|                                                                   |
|  +------------------------------------------------------------+  |
|  |  Unpark Selected Payments                             [X]  |  |
|  |------------------------------------------------------------|  |
|  |                                                            |  |
|  |  Are you sure you want to unpark these payments?           |  |
|  |                                                            |  |
|  |  Payments selected:    2                                   |  |
|  |  Combined total:       R 42 525,00                         |  |
|  |                                                            |  |
|  |  These payments will be returned to the ready list.        |  |
|  |                                                            |  |
|  |               [Cancel]    [Confirm Unpark]                 |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

## Elements

| Element | Type | Description |
|---------|------|-------------|
| Modal backdrop | Overlay | Dims the background screen; clicking outside dismisses |
| [X] close button | Button | Dismisses modal without action |
| Title | Heading | "Unpark Payment" (single) or "Unpark Selected Payments" (bulk) |
| Confirmation text | Text | "Are you sure you want to unpark this payment?" / "...these payments?" |
| Agent (single only) | Read-only text | AgentName + AgentSurname |
| Claim Date (single only) | Read-only text | ClaimDate in DD/MM/YYYY format |
| Commission Amount (single only) | Read-only text | CommissionAmount in R x xxx,xx format |
| Payments selected (bulk only) | Read-only text | Count of selected payment IDs |
| Combined total (bulk only) | Read-only text | Sum of CommissionAmount for selected payments; R x xxx,xx format |
| [Cancel] button | Button | Dismisses modal; no API call; no grid changes |
| [Confirm Unpark] button | Button | Calls PUT /v1/payments/unpark with PaymentIds; on success moves payment(s) from Parked Grid back to Main Grid; on failure shows inline error on Screen 2 |

## User Actions

- **Click [Cancel] or [X] or outside modal:** Dismisses modal; Parked Grid unchanged.
- **Click [Confirm Unpark]:** Calls PUT /v1/payments/unpark with { PaymentIds: [id] } (single) or { PaymentIds: [...ids] } (bulk); on success moves payment(s) from Parked Grid to Main Grid and closes modal; on failure shows error message.

## Navigation

- **From:** Screen 2 Parked Grid — single "Unpark" button or "Unpark Selected" button.
- **To:** Returns to Screen 2; no navigation change on success (grids update in place).
