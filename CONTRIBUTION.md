# Contributing to Kerbwise Courier

## Set up your development environment

Install Flutter 3.44+, JDK 17, the Android SDK with platform tools, and Node.js 18+. Check the toolchain, install dependencies, and start the mock API from the project root.

```sh
flutter doctor
flutter pub get
node courier-server.js
```

Keep the calm mock API running in that terminal. Use a second terminal to launch the app on an Android emulator or a USB-connected phone. The setup commands, including USB port forwarding, are in the [Android setup guide](README.md#run-on-android).

The mock starts with 60 deliveries on port 4000. Restart it to reset the demo data. The [API notes](docs/courier-api-notes.md) describe the request and response formats.

## Find your way around

| Area | Where to look |
| --- | --- |
| App startup and API URL | [`lib/main.dart`](lib/main.dart) |
| Delivery data and JSON parsing | [`lib/models/delivery.dart`](lib/models/delivery.dart) |
| Home and delivery detail views | [`lib/pages`](lib/pages) |
| Loading, validation, and completion state | [`lib/controllers`](lib/controllers) |
| Courier API and Android dialer | [`lib/services`](lib/services) |
| Shared widgets, theme, and formatting utilities | [`lib/core`](lib/core) |
| Widget tests with a mock HTTP client | [`test/courier_app_test.dart`](test/courier_app_test.dart) |

## Make and verify a change

Keep each change focused. When changing delivery behavior, add or update a widget test that exercises the courier’s action and checks the resulting UI or API request. The tests run locally with the API and emulator stopped.

```sh
dart format lib test
flutter analyze
flutter test
```

For UI or API changes, also exercise the affected flow against the calm mock on Android. The [manual walkthrough](README.md#check-the-courier-flow) covers pagination, cash validation, prepaid completion, and recovery after a connection error. Use the mock’s sample customer data in screenshots and test fixtures.

When opening a pull request, summarize what changed and why, and list the checks you ran. For UI changes, include a screenshot or short recording of the affected screen. For a bug fix, include the steps that reproduced the issue.
