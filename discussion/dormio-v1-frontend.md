# Dormio V1 Frontend Discussion

**Status:** Working discussion
**Related documents:** [V1 Product Requirements](dormio-v1-scope.md) · [V1 High-Level Architecture](dormio-v1-architecture.md)

## Confirmed Decisions

- The first screen after staff sign-in is the **Overview**.
- Use a **mobile-first** approach: design the core workflows at phone widths first, then adapt them for larger screens.
- Make Overview a task-focused starting point with this agreed hierarchy:
	1. A header with the selected month and a clear entry point to a common action.
	2. A short, urgency-ordered **Needs attention** list with direct links to upcoming move-ins, billing or meter-reading work, unpaid or partially paid renter balances, and open maintenance issues.
	3. Room counts for **Available**, **Reserved**, and **Occupied**, separate from maintenance status.
	4. A monthly summary of recorded income, expenses, and net, clearly labeled with the reporting month; describe income as recorded income, not cash received.

## UX Recommendations (Proposed)

### Mobile and interaction design

- Ensure ordinary content reflows at a 320 CSS-pixel viewport without horizontal scrolling. Use a readable list or summary layout instead of a wide table on narrow screens.
- Make frequent touch controls comfortably large. WCAG 2.2 sets a 24-by-24 CSS-pixel minimum target size or spacing exception; consider 44-by-44 targets for primary actions where practical.
- Keep mobile navigation focused on the most-used destinations, with a clearly labeled way to reach secondary sections.
- Use visible field labels, preserve entered data when validation fails, and show both a form-level error summary and specific field errors.
- Communicate room and payment states with text as well as color. Give clear feedback after actions and explain consequential occupancy or financial changes before confirmation.

## Open Frontend Decisions

- Which common action should be most prominent on Overview?
- What belongs in primary navigation, and how should navigation work on mobile?
- Which workflow should follow the app shell and Overview?
- What visual direction and information density best fit the landlord's day-to-day work?

## UX References

- [WCAG 2.2: Reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html)
- [WCAG 2.2: Target Size (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html)
- [Nielsen Norman Group: 10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)
- [GOV.UK Design System: Error Summary](https://design-system.service.gov.uk/components/error-summary/)
