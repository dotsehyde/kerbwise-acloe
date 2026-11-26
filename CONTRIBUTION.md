# Contributing to Kerbwise Courier

## Set up your development environment

Install Flutter 3.44+, JDK 17, the Android SDK with platform tools, and Node.js 18+. Check the toolchain, install dependencies, and start the mock API from the project root.

```sh
flutter doctor
flutter pub get
node courier-server.js
```

Keep the calm mock API running in that terminal. Use a second terminal to launch the app on an Android emulator or a USB-connected phone. The setup commands, including USB port forwarding, are in the [Android setup guide](README.md#run-on-android).

The mock starts with 60 deliveries on port 4000. Restart it to reset the demo data. The [API notes](courier-api-notes.md) describe the request and response formats.

## Find your way around

| Area | Where to look |
| --- | --- |
| App startup and API URL | [`lib/main.dart`](lib/main.dart) |
| API requests, pagination, and completion retries | [`lib/courier_api.dart`](lib/courier_api.dart) |
| Delivery models, GBP amounts, and London time | [`lib/delivery.dart`](lib/delivery.dart) |
| Delivery list and progress | [`lib/deliveries_screen.dart`](lib/deliveries_screen.dart) |
| Delivery details, customer dialer, and handover | [`lib/delivery_screen.dart`](lib/delivery_screen.dart) |
| Shared colors and screen states | [`lib/courier_theme.dart`](lib/courier_theme.dart) |
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
