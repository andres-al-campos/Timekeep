# Activity log

Updated 2026-10-25 11:38, at 1.0.1.

Every app session with the time it started, grouped by day, so you
can see when you used each app and not just how long.

## Sub-features

- Sessions newest first, under a header for each day, with app icon, start
  time and length. The app in use now shows as active.
- **Search** by app name.
- Tap a session for that app ([One app](one-app.md)).
- With no events yet, an empty state with a Setup Guide button.

## How to get to it

Open Timekeep; it's the first page. Swipe left for All apps.

## Driving it

No check yet. A drive would seed open and close events and read the sessions
shown; there's no test target to run one.

By hand only: open and close a tracked app and see the session appear.

## Calls

- 2026-10-23 00:53, 1.0.1. A session runs from an app's open until that app closes or another app
  opens, whichever comes first, so the timeline shows when each app was in
  front. Either end is exact, not estimated. The user, 2026-10-23.

## Gotchas

- How sessions are stitched from events (it applies to every screen):
  - An open followed by the same app's close is one session.
  - An open followed by another app's open ends the first session at that
    moment.
  - An app opened again with no close in between restarts its session at the
    later open, and the time before it is dropped.
  - A close for an app that isn't open is ignored.
- Locking the phone logs no close (seen on the phone, 2026-10-23). A session
  runs on through the locked time until the next app opens, so its length and
  the totals come out longer than Screen Time's.
- A session ended by the next app's open isn't an estimate (see Calls). The "~" a row shows for an
  estimated length is left over from a debounce removed in March 2026 and
  never appears now.
