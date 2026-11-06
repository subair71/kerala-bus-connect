# Sponsor banner design

Home sponsors now use the supplied reference's white rounded banner, square advertiser image or wordmark, black pill action and grey circular close control. On narrow screens or enlarged text, the action moves below the copy to stay usable.

The existing location-based Firebase/sample selection, five-second rotation, manual arrows, reduced-motion and background/touch/hover pauses remain. Closing hides the carousel for that location for the current app session, cancels its timer and releases the carousel's subscriptions. A different boarding location can still display its own sponsors. Reloading resets session dismissals.

Live campaigns use the existing website action. Demo campaigns show their complete content and disclosure in an information dialog; they never contact an advertiser. Missing images use a local wordmark. Ads remain confined to home.

## Screenshots

- [Mobile home](screenshots/sponsor-banner-mobile.png)
- [Desktop home](screenshots/sponsor-banner-desktop.png)
- [Wide banner](screenshots/sponsor-banner-wide.png)
- [Narrow banner](screenshots/sponsor-banner-narrow.png)

## Validation

Architecture enforcement (84 Dart files; zero application setState), flutter analyze, all 56 tests and 34 layout captures passed in review. Coverage includes 320px, 390px and 760px sponsor banners, desktop home, 2× text, rotation, dismissal, sample/live recovery and sample detail actions.

The pull-request workflow also validates formatting, builds the release web app and exercises desktop Chromium, Android Chrome and iPhone WebKit navigation and reload.
