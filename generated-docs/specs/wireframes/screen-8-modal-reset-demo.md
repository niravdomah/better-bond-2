# Screen: Reset Demo Confirmation Modal

## Purpose
Confirmation dialog before resetting the application demo dataset to its initial state. Admin-only action. After confirmation, calls POST /demo/reset-demo and refreshes all application data.

## Access
Admin role only. The Reset Demo button is not shown to Viewer users.

## Wireframe

```
+------------------------------------------------------------------+
|  (backdrop: screen behind is dimmed)                              |
|  (can be triggered from any screen)                               |
|                                                                   |
|  +------------------------------------------------------------+  |
|  |  Reset Demo Data                                      [X]  |  |
|  |------------------------------------------------------------|  |
|  |                                                            |  |
|  |  Are you sure you want to reset the demo data?             |  |
|  |                                                            |  |
|  |  This will restore all payments and batches to their       |  |
|  |  original demo state. All changes made during this         |  |
|  |  session (parked/unparked payments, initiated batches)     |  |
|  |  will be lost.                                             |  |
|  |                                                            |  |
|  |  This action cannot be undone.                             |  |
|  |                                                            |  |
|  |               [Cancel]    [Reset Demo]                     |  |
|  +------------------------------------------------------------+  |
|                                                                   |
+------------------------------------------------------------------+

── SUCCESS STATE (inline banner, shown after successful reset) ──────────────────
|                                                                                  |
|  [✓] Demo data has been reset successfully. The application data has refreshed. |
|                                                                              [X] |
|                                                                                  |
+-----------------------------------------------------------------------------------+
```

## Elements

| Element | Type | Description |
|---------|------|-------------|
| Modal backdrop | Overlay | Dims the background screen |
| [X] close button | Button | Dismisses modal without action |
| Title | Heading | "Reset Demo Data" |
| Warning text | Text | Explains that all session changes will be lost and action cannot be undone |
| [Cancel] button | Button | Dismisses modal; no API call; no data changes |
| [Reset Demo] button | Button | Calls POST /demo/reset-demo; on success closes modal and shows success banner, then refreshes all application data; on failure shows inline error |
| Success banner | Alert | Shown after successful reset; confirms demo data has been restored |

## User Actions

- **Click [Cancel] or [X] or outside modal:** Dismisses modal; no changes made.
- **Click [Reset Demo]:** Calls POST /demo/reset-demo; on success closes modal, shows success confirmation message, and all screens/data refresh to initial demo state; on failure shows inline error message.

## Navigation

- **From:** Any screen — triggered by clicking the "Reset Demo" button in the navigation bar (Admin only).
- **To:** Returns to the current screen after dismissal; data refreshes in place after successful reset.

## State Notes

- After a successful reset, the application should re-fetch data for the current screen so the user sees the freshly restored demo data without requiring a full page reload.
- The [Reset Demo] button in the nav bar is visible only to Admin role users.
