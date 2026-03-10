# Epic 1: Application Shell and Navigation

## Description

Establishes the foundational application shell: persistent navigation bar with MortgageMax branding, route structure for all three screens, SSO/OAuth session authentication with 401 redirect, RBAC enforcement (Viewer redirect from Payments Made to Dashboard), shared ZAR currency and DD/MM/YYYY date formatting utilities, and API client base URL configured to http://localhost:8042.

**Implementation order:** Story 3 (utilities) → Story 1 (shell and navigation) → Story 2 (authentication)

## Stories

1. **App Shell, Navigation Bar, and Route Structure** - Replaces the placeholder home page with the real app shell. Persistent NavBar with MortgageMax branding, links to all 3 screens, active-link highlighting, RBAC-gated visibility, and route stubs for `/payment-management` and `/payments-made`. | File: `story-1-app-shell-navigation-and-route-structure.md` | Status: Pending
2. **Authentication — Session Guard and 401 Redirect** - Ensures all app routes are protected so unauthenticated users are redirected to sign-in. Wires 401 API error handler to redirect to sign-in when sessions expire. Sign-in page with email/password form and error messaging. | File: `story-2-authentication-session-guard-and-401-redirect.md` | Status: Pending
3. **Shared Formatting Utilities — ZAR Currency and DD/MM/YYYY Dates** - Pure utility functions for ZAR currency formatting, DD/MM/YYYY date formatting, and commission percentage display. Small, testable in isolation. | File: `story-3-shared-formatting-utilities.md` | Status: Pending
