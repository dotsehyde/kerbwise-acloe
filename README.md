# Kerbwise Courier

An Android courier app built with **Flutter**. It uses the calm mock API for Step 1.

For development setup and pull request guidance, see [Contributing](CONTRIBUTION.md).

## Screenshots

| Today’s deliveries | Delivery details | Cash validation |
| :---: | :---: | :---: |
| [<img src="screenshot/home.png" width="220" alt="Today’s delivery list with progress for all 60 deliveries">](screenshot/home.png) | [<img src="screenshot/delivery-details.png" width="220" alt="Delivery details showing the address, call button, due time, and cash to collect">](screenshot/delivery-details.png) | [<img src="screenshot/cash-validation.png" width="220" alt="Cash validation message showing the exact amount required to complete the delivery">](screenshot/cash-validation.png) |

## Clone the repository

```sh
git clone https://github.com/dotsehyde/kerbwise-acloe.git
cd kerbwise-acloe
```

## Set up and start the API

Install Node.js 18+ and Flutter 3.44+ with the Android SDK, Android platform tools (`adb`), and JDK 17. From the repository directory, check your toolchain, install the Flutter dependencies, and start the calm mock API.

```sh
flutter doctor
flutter pub get
node courier-server.js
```

Leave this terminal running. The API listens on port 4000. Restarting it resets the deliveries.

## Run on Android

Open a second terminal in the `kerbwise-acloe` directory. Start an Android Studio emulator or connect a phone over USB. For a phone, enable USB debugging and accept the debugging prompt. Find your device ID with `flutter devices`.

**Android Studio emulator**

```sh
flutter run -d emulator-5554
```

Use the ID shown by `flutter devices` if yours differs. The app defaults to `http://10.0.2.2:4000`, which reaches the host from the emulator.

**Android phone over USB**

```sh
adb -s PHONE_ID reverse tcp:4000 tcp:4000
flutter run -d PHONE_ID --dart-define=COURIER_API_URL=http://127.0.0.1:4000
```

Replace `PHONE_ID` with the connected phone’s ID. Keep the USB connection active. The debug build allows HTTP for the local mock.

## Check the courier flow

Use the calm API for this walkthrough.

- The list should show 60 deliveries. Scroll to the bottom to find Oscar Reid, delivery #60.
- Open George Novak, delivery #7, to see the address and cash due. **Call customer** opens the Android dialer with the number filled in. Enter `262.49` and tap **Mark delivered** to see the cash validation, then enter `262.50` to complete it.
- Open Farah Bennett, delivery #6. **Mark delivered** records the handover without a cash entry. Return to the list to see the updated status and count.
- Stop the API and tap **Refresh deliveries** to see the last loaded route. Restart the API and refresh again.

## Try real conditions

Stop the calm server and run `node courier-server.js --real`. Refresh the app to load the busy-day route. Due times use London time, and earlier and upcoming deliveries appear in separate sections.

Open a delivery from the loaded route, stop the server, then tap **Mark delivered** with the exact amount for a cash delivery. The app shows **Saved on this phone. Waiting to sync.** Restart the server in real mode and return to the app. The pending handover retries automatically with the original amount and key. **Refresh deliveries** also checks for pending handovers. The mock resets its server-side data on each restart.

Saved handovers survive an app restart. Customer names, addresses, phone numbers, and notes are held in memory, so a cold start without a connection shows saved handovers by delivery ID until the route reloads. The [Step 2 decisions](DECISIONS.md) explain the retry and cash-handling tradeoffs.

## Project structure

The Flutter app follows Model–View–Controller (MVC).

```text
lib/
├── models/       # Delivery and handover data
├── pages/        # Home and delivery detail screens
├── controllers/  # Loading, cash validation, and completion state
├── services/     # Courier API, handover queue, and Android dialer
└── core/         # Shared app code
    ├── theme/    # Colors and Material theme
    ├── shared/   # Reusable screen messages
    └── utils/    # GBP and London time formatting
```

The pages rebuild when their controllers publish state changes. When the API confirms a handover, the detail page reports the updated delivery to the home controller, which updates the row and progress count.

The Android host project lives in `android/`. The calm mock runs from `courier-server.js`, and its endpoints and response formats are documented in the [Courier API notes](docs/courier-api-notes.md).

## Run the checks

```sh
flutter analyze
flutter test
```

The [widget tests](test/courier_app_test.dart) cover pagination, cash and prepaid completion, duplicate taps, and a lost connection. The [queue tests](test/completion_queue_test.dart) cover restart recovery, rate limiting, terminal conflicts, and local write failures. These checks use a mock HTTP client and can run with the server and emulator stopped.
