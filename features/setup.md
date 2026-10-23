# Setup

Updated 2026-10-23 17:26, at 1.0.1.

Getting events in: two Shortcuts automations tell Timekeep each time a chosen
app opens or closes. iOS has no API that hands an app your usage, so this is
the only way in.

## Sub-features

- **Onboarding** on first launch: three pages ending in the setup steps and
  Get Started.
- **Setup guide**: the steps to build the two automations (App trigger → Is
  Opened → Get Name of Current App → Log App Event with Opened; then the same
  with Is Closed and Closed). To track more apps, add them to both triggers.
- **Log App Event**, Timekeep's Shortcuts action: app name and Opened or
  Closed. On an open it also looks up the app's icon.
- **View Raw Events**: every logged event, newest first.
- **Delete All Data**, after a confirmation.

## How to get to it

Onboarding shows once, on first launch. After that, the ⓘ button on the
Activity log, or Setup Guide on its empty state.

## Driving it

No check yet. The automations live in the Shortcuts app, which can't be
driven from a test. The Log App Event action could be called from a unit test
target, which doesn't exist yet.

By hand only: build the two automations, open a tracked app, and see the event
in View Raw Events.

## Gotchas

- The app icon is looked up by sending the app's name to the App Store
  search. It's the one thing that leaves the phone; events and sessions don't.
- The Is Closed trigger doesn't fire when the phone locks (seen 2026-10-23);
  see the Activity log's Gotchas for what that does to sessions.
- An app not in the automations' triggers is never seen: its time goes to the
  app opened before it, until the next event.
