# Story: Authentication — Session Guard and 401 Redirect

**Epic:** Application Shell and Navigation | **Story:** 2 of 3 | **Wireframe:** Sign-in screen (Screen 0)

## Story Metadata

| Field | Value |
|-------|-------|
| **Route** | `/sign-in` (sign-in page), protected route group wrapping `/`, `/payment-management`, `/payments-made` |
| **Target File** | `app/(auth)/sign-in/page.tsx` or equivalent sign-in page; route group layout for protected routes |
| **Page Action** | `modify_existing` if auth structure already present; `create_new` if not |

## User Story

**As a** MortgageMax portal user **I want** all application screens to require authentication **So that** unauthenticated users cannot access protected data and expired sessions are handled gracefully with a redirect to sign-in.

## Acceptance Criteria

### Unauthenticated Access — Redirect to Sign-In

- [ ] Given I am not signed in and I visit `/`, when the page loads, then I am redirected to the sign-in page
- [ ] Given I am not signed in and I visit `/payment-management`, when the page loads, then I am redirected to the sign-in page
- [ ] Given I am not signed in and I visit `/payments-made`, when the page loads, then I am redirected to the sign-in page

### Sign-In Page — Form

- [ ] Given I am on the sign-in page, when the page renders, then I see an email input field and a password input field
- [ ] Given I am on the sign-in page, when the page renders, then I see a submit button to sign in

### Sign-In Page — Happy Path

- [ ] Given I am on the sign-in page, when I submit valid Admin credentials, then I am signed in and redirected to `/` (Dashboard)

### Sign-In Page — Error Handling

- [ ] Given I am on the sign-in page, when I submit invalid credentials, then I see an error message indicating the credentials are incorrect (e.g., "Invalid email or password")

### Session Expiry — 401 Redirect

- [ ] Given I am signed in and the API returns a 401 response, when the error is handled, then I am redirected to the sign-in page

## API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/v1/auth/token` or equivalent | Authenticate user and obtain session token |

Note: The exact sign-in endpoint should be confirmed in `generated-docs/specs/api-spec.yaml`. The existing `handleErrorResponse` in `web/src/lib/api/client.ts` throws on 401 but does not currently redirect — this story must add the redirect behaviour to that handler.

## Implementation Notes

- All protected routes (`/`, `/payment-management`, `/payments-made`) should be wrapped in a protected route group layout that checks for an active session and redirects to sign-in if none exists.
- The `handleErrorResponse` function in `web/src/lib/api/client.ts` currently throws on 401. This story must extend it to also trigger a client-side redirect to the sign-in page (e.g., via `window.location` or a Next.js router call) so session expiry is handled globally without each page needing individual 401 handling.
- The existing `UserRole` enum flag: `ADMIN` = Admin, all other values = Viewer. The auth context must expose the current user's role for RBAC checks in Story 1 and downstream epics.
- SSO/OAuth token handling: session token should be stored in a cookie or secure storage consistent with the existing auth library setup.
