# Story: Shared Formatting Utilities — ZAR Currency and DD/MM/YYYY Dates

**Epic:** Application Shell and Navigation | **Story:** 3 of 3 | **Wireframe:** N/A (utility functions, no UI)

## Story Metadata

| Field | Value |
|-------|-------|
| **Route** | N/A (utility functions only) |
| **Target File** | `lib/utils/formatters.ts` (or equivalent shared utilities location) |
| **Page Action** | `create_new` |

## User Story

**As a** developer building the MortgageMax portal **I want** shared pure utility functions for ZAR currency, date, and commission percentage formatting **So that** all screens display monetary and date values in a consistent, localised format (ZAR with South African conventions, DD/MM/YYYY dates).

## Acceptance Criteria

### ZAR Currency Formatting

- [ ] Given a ZAR amount of 1234567.89, when formatted, then the output is "R 1 234 567,89" (space thousands separator, comma decimal separator)
- [ ] Given a ZAR amount of 0, when formatted, then the output is "R 0,00"
- [ ] Given a null or undefined value, when formatted, then the output is an empty string (not "0", "R 0,00", or any placeholder)
- [ ] Given an empty string value, when formatted, then the output is an empty string

### Date Formatting

- [ ] Given a date string "2024-03-15", when formatted, then the output is "15/03/2024"
- [ ] Given a null or undefined date value, when formatted, then the output is an empty string (not "undefined" or a placeholder)
- [ ] Given an empty string date value, when formatted, then the output is an empty string

### Commission Percentage Formatting

- [ ] Given a commission amount of 9450 and a bond amount of 1000000, when the commission percentage is computed, then the display value is "0.945%"

## API Endpoints

No API endpoints required for this story. These are pure formatting utility functions.

## Implementation Notes

- ZAR formatting uses South African locale conventions: "R" prefix, space as thousands separator, comma as decimal separator (e.g., "R 1 234 567,89"). This is NOT the standard `Intl.NumberFormat('en-ZA')` output (which uses commas for thousands) — confirm the exact format against the wireframes.
- All formatter functions should gracefully handle null, undefined, and empty string inputs by returning an empty string, not a fallback display value.
- Commission percentage = (commissionAmount / bondAmount) * 100, formatted to 3 decimal places with a "%" suffix.
- These utilities will be consumed by Epic 2 (Dashboard charts and KPI cards), Epic 3 (Payment Management grids), and Epic 4 (Payments Made grid). Writing them first (implementation order: Story 3 → 1 → 2) unblocks all downstream formatting requirements.
- Functions should be exported as named exports from a single file for easy import across the codebase.
