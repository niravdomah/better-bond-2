# Story: App Shell, Navigation Bar, and Route Structure

**Epic:** Application Shell and Navigation | **Story:** 1 of 3 | **Wireframe:** Navigation bar visible on all screens in wireframes

## Story Metadata

| Field | Value |
|-------|-------|
| **Route** | `/` (home page), `/payment-management` (stub), `/payments-made` (stub) |
| **Target File** | `app/page.tsx` (modify existing — replace placeholder), `app/payment-management/page.tsx` (create new), `app/payments-made/page.tsx` (create new) |
| **Page Action** | `modify_existing` for home page; `create_new` for route stubs |

## User Story

**As a** MortgageMax portal user **I want** a persistent navigation bar with links to all application screens **So that** I can navigate between the Dashboard, Payment Management, and Payments Made screens from any page, with RBAC controlling which links I see.

## Acceptance Criteria

### Home Page — Placeholder Replacement

- [ ] Given I visit `/`, when the page loads, then I see the application shell with the persistent navigation bar (not the Next.js placeholder text)

### Persistent Navigation Bar — Branding

- [ ] Given I am on any screen, when the page renders, then I see the navigation bar containing the MortgageMax logo or brand name on the left side
- [ ] Given I am on any screen, when the page renders, then the navigation bar is visible at the top of the page on all routes (`/`, `/payment-management`, `/payments-made`)

### Persistent Navigation Bar — Links

- [ ] Given I am on any screen, when the page renders, then the navigation bar contains a "Dashboard" link
- [ ] Given I am on any screen, when the page renders, then the navigation bar contains a "Payment Management" link
- [ ] Given I am an Admin and on any screen, when the page renders, then the navigation bar contains a "Payments Made" link that is visible and enabled
- [ ] Given I am a Viewer (non-Admin) and on any screen, when the page renders, then the "Payments Made" link is not visible or is disabled

### Persistent Navigation Bar — RBAC: Reset Demo

- [ ] Given I am an Admin and on any screen, when the page renders, then a "Reset Demo" button is visible in the navigation bar
- [ ] Given I am a Viewer and on any screen, when the page renders, then the "Reset Demo" button is not visible

### Navigation — Routing

- [ ] Given I click "Dashboard" in the navigation bar, when the click is processed, then I navigate to `/`
- [ ] Given I click "Payment Management" in the navigation bar, when the click is processed, then I navigate to `/payment-management`
- [ ] Given I am an Admin and I click "Payments Made" in the navigation bar, when the click is processed, then I navigate to `/payments-made`

### Navigation — Active Link Highlighting

- [ ] Given I am on `/`, when the page renders, then the "Dashboard" navigation link is visually active or highlighted
- [ ] Given I am on `/payment-management`, when the page renders, then the "Payment Management" navigation link is visually active or highlighted

### Route Stubs

- [ ] Given `/payment-management` exists, when I navigate to it, then I see a page heading "Payment Management" (stub; full content in Epic 3)
- [ ] Given `/payments-made` exists as Admin-accessible, when an Admin navigates to it, then I see a page heading "Payments Made" (stub; full content in Epic 4)

### RBAC — Viewer Redirect from Payments Made

- [ ] Given I am a Viewer and I navigate directly to `/payments-made`, when the page loads, then I am redirected to `/` (Dashboard)

## API Endpoints

No API endpoints required for this story. RBAC role is derived from the existing authentication context (UserRole enum: ADMIN maps to Admin, all other values map to Viewer).

## Implementation Notes

- The existing `UserRole` enum must be mapped: `ADMIN` = Admin role (full access), all other values = Viewer (restricted access).
- NavBar should be rendered in the root layout (`app/layout.tsx`) so it persists across all routes without re-mounting.
- Active-link highlighting should use Next.js `usePathname()` hook to compare current path to link href.
- Viewer redirect from `/payments-made` should be a client-side redirect in the page component using `useRouter()` after checking the user's role from auth context.
- The "Reset Demo" button in the nav bar is a visible affordance only; full Reset Demo functionality is implemented in Epic 4.
- NavBar is a `"use client"` component (requires `usePathname` and auth context).
