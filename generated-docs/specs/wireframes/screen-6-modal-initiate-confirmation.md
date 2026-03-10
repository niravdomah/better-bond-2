# Screen: Initiate Payment Confirmation Modal

## Purpose
Confirmation dialog displayed before creating a payment batch. Summarises the count and total value of all payments currently visible in the Main Grid (respecting any active filters). Confirming creates one batch per agency from the visible payments.

## Access
Admin role only. The Initiate Payment button is disabled for Viewer users so this modal is never triggered for Viewers.

## Wireframe

```
+------------------------------------------------------------------+
|  (backdrop: screen behind is dimmed)                              |
|                                                                   |
|  +------------------------------------------------------------+  |
|  |  Initiate Payment                                     [X]  |  |
|  |------------------------------------------------------------|  |
|  |                                                            |  |
|  |  Are you sure you want to initiate payment for all         |  |
|  |  payments currently in the ready list?                     |  |
|  |                                                            |  |
|  |  Payments to process:  12                                  |  |
|  |  Total value:          R 135 678,00                        |  |
|  |                                                            |  |
|  |  Note: This will create one invoice per agency for all     |  |
|  |  currently visible ready payments.                         |  |
|  |                                                            |  |
|  |          [Cancel]    [Confirm — Initiate Payment]          |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

## Elements

| Element | Type | Description |
|---------|------|-------------|
| Modal backdrop | Overlay | Dims the background screen; clicking outside dismisses |
| [X] close button | Button | Dismisses modal without action |
| Title | Heading | "Initiate Payment" |
| Confirmation text | Text | States that all currently visible ready payments will be processed |
| Payments to process | Read-only text | Count of all payments currently visible in Main Grid |
| Total value | Read-only text | Sum of CommissionAmount for all visible Main Grid payments; R x xxx,xx format |
| Note | Informational text | Clarifies one invoice per agency will be generated |
| [Cancel] button | Button | Dismisses modal; no API call; Main Grid unchanged |
| [Confirm — Initiate Payment] button | Button | Calls POST /v1/payment-batches with PaymentIds of all visible Main Grid payments and LastChangedUser header; on success closes this modal and opens screen-7 success modal; on failure shows inline error on Screen 2 |

## User Actions

- **Click [Cancel] or [X] or outside modal:** Dismisses modal; Main Grid and Parked Grid unchanged.
- **Click [Confirm — Initiate Payment]:** Calls POST /v1/payment-batches with { PaymentIds: [...all visible main grid ids] }; on success closes this modal and opens Initiate Payment Success modal (screen-7); on failure closes modal and shows inline error message on Screen 2 with grids unchanged.

## Navigation

- **From:** Screen 2 "Initiate Payment" button.
- **To:** On cancel — back to Screen 2 (no change); on confirm success — opens screen-7 (Initiate Payment Success modal); on confirm failure — back to Screen 2 with error message.
