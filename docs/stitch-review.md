# Stitch implementation review

The supplied ZIP was extracted and all three HTML files, screenshots, the hotel asset and DESIGN.md were inspected before application changes.

| Reference detail | Native Flutter implementation |
| --- | --- |
| Plus Jakarta Sans, teal and pale surfaces | Bundled font and shared theme tokens |
| Desktop navigation | Five existing destinations in the top bar |
| Mobile navigation | Five bottom destinations with labels |
| Location-specific sponsor above search | Swipeable PageView with arrows, dots and provider-selected location |
| From/to controls and quick stops | Stable text controllers, swap/clear, corridor chips and day filters |
| Time bands and cards | Native service cards using only known schedule values |
| Desktop stop sequence | Read-only timetable sidebar; scrollable details sheet on mobile |
| Other existing screens | Shared cards, inputs, buttons, spacing and typography |

Reference-only GPS claims, unsupported fares/platforms/ratings and nonfunctional notification/station-switcher controls were not introduced. Sample schedules and advertisements are visibly identified. The supplied reference's broken image placeholders are represented with native icons.

Automated captures in the `stitch-screenshots` artifact cover desktop, mobile, narrow mobile, full-height mobile, Routes, Owner, Tracking and Crew. The `stitch-browser-screenshots` artifact captures the compiled release web application, with the current Firebase response, at desktop and mobile viewports.

Validation includes 31 domain/provider/widget tests and eight capture scenarios. Real production owner records are not mutated during validation. Existing production authentication/security configuration is unchanged; physical Android/iOS devices and authenticated production CRUD still need an acceptance run.

## Saved visual evidence

- [Desktop sample layout](screenshots/desktop.jpg)
- [Mobile sample layout](screenshots/mobile.jpg)
- [Desktop release browser](screenshots/browser-desktop.jpg)
- [Mobile release browser](screenshots/browser-mobile.jpg)

Sample layout captures use deterministic repository fixtures. Browser captures use the configured Firebase project without test writes. The current Aluva → Kaloor live query has no matching service, so the browser correctly shows zero results instead of inserting fictional schedules.
