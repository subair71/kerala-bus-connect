# FindMyBus — unified reference design

The white-and-orange home-screen style now extends to Routes, owner sign-in and registration, the owner workspace, Tracking, Crew, business/route/timetable editors, stop timings and confirmation dialogs.

Shared tokens define the white surfaces, subtle grey outlines, orange actions, muted text and rounded controls. Every tab uses the same header and flat mobile navigation. Timetable controls wrap their content for long stop names and enlarged text.

The existing Riverpod providers, Firebase repositories, validation and write guards remain in place. Sponsored ads remain confined to home, and mobile results continue to open in a bottom sheet.

## Reviewed screenshots

These are native Flutter captures using isolated test repositories. Owner records shown as “Test operator” / “Test bus” exist only in the test harness; these captures do not write to Firebase.

| Screen | Screenshot |
| --- | --- |
| Routes, mobile | [Open](screenshots/unified-mobile-routes.png) |
| Owner sign-in, mobile | [Open](screenshots/unified-mobile-owner.png) |
| Tracking, mobile | [Open](screenshots/unified-mobile-tracking.png) |
| Crew, mobile | [Open](screenshots/unified-mobile-crew.png) |
| Owner workspace, desktop | [Open](screenshots/unified-desktop-workspace.png) |
| Route editor | [Open](screenshots/unified-route-editor.png) |
| Timetable editor | [Open](screenshots/unified-timetable-editor.png) |
| Stop timings | [Open](screenshots/unified-stop-details.png) |

## Verification

The design review passed architecture enforcement (84 Dart files, zero application setState), flutter analyze, all 52 tests and all 30 screenshot/layout checks. Coverage includes 320–1440px widths, 2× text, an open keyboard, all tabs, signed-in owner fixtures, editors and delete confirmation.

The pull-request validation workflow additionally enforces formatting, repeats the regression checks, produces a release web build, and runs Chromium desktop, Android Chrome and iPhone WebKit checks. Browser checks now visit all feature tabs, confirm ads stay out of those tabs, and check Firebase startup and reload.

Authenticated owner mutations are exercised with isolated fake repositories in tests. No production owner records are created, edited or deleted for visual review.
