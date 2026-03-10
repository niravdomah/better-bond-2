# Screen: Initiate Payment Success Modal

## Purpose
Success confirmation modal displayed after a payment batch is successfully created. Informs the user the payment batch has been created and provides a "View Invoice" button that navigates directly to Screen 3 (Payments Made), where the new batch is immediately visible.

## Access
Admin role only (displayed after a successful POST /v1/payment-batches, which is an Admin-only action).

## Wireframe

```
+------------------------------------------------------------------+
|  (backdrop: screen behind is dimmed)                              |
|  (Main Grid on Screen 2 has already been updated — payments       |
|   processed are removed from the Main Grid)                       |
|                                                                   |
|  +------------------------------------------------------------+  |
|  |  Payment Initiated Successfully                       [X]  |  |
|  |------------------------------------------------------------|  |
|  |                                                            |  |
|  |  ✓  Your payment batch has been created.                   |  |
|  |                                                            |  |
|  |  The processed payments have been removed from the         |  |
|  |  ready list. An invoice has been generated per agency.     |  |
|  |                                                            |  |
|  |  You can download the invoice(s) from the                  |  |
|  |  Payments Made screen.                                     |  |
|  |                                                            |  |
|  |               [Close]    [View Invoice]                    |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+
```

## Elements

| Element | Type | Description |
|---------|------|-------------|
| Modal backdrop | Overlay | Dims Screen 2 behind the modal |
| [X] close button | Button | Dismisses modal; stays on Screen 2 |
| Title | Heading | "Payment Initiated Successfully" |
| Success icon / checkmark | Visual indicator | Confirms the action completed |
| Success message | Text | Explains batch was created and payments have been removed from ready list |
| Invoice note | Text | Indicates invoices are available on the Payments Made screen |
| [Close] button | Button | Dismisses modal; user remains on Screen 2 (Main Grid now shows remaining/filtered payments) |
| [View Invoice] button | Button | Navigates to Screen 3 (Payments Made); newly created batch is immediately visible in the grid |

## User Actions

- **Click [Close] or [X]:** Dismisses modal; user remains on Screen 2 with updated Main Grid (processed payments removed).
- **Click [View Invoice]:** Navigates to Screen 3 (Payments Made); newly created batch is immediately visible at top of grid.

## Navigation

- **From:** Screen-6 (Initiate Payment Confirmation modal) upon successful POST /v1/payment-batches.
- **To:** Screen 2 (stay; on Close); Screen 3 (Payments Made; on View Invoice).

## State Notes

By the time this modal opens:
- The POST /v1/payment-batches call has returned 200.
- The processed payments have been removed from the Main Grid on Screen 2.
- The payment batch is synchronously created and will appear in Screen 3 immediately on navigation.
