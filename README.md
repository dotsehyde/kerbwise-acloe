# Kerbwise Courier

An Android courier app built with **Flutter**. It uses the calm mock API for Step 1.

For development setup and pull request guidance, see [Contributing](CONTRIBUTION.md).

## Screenshots

| Today’s deliveries | Delivery details | Cash validation |
| :---: | :---: | :---: |
| [<img src="screenshot/home.png" width="220" alt="Today’s delivery list with progress for all 60 deliveries">](screenshot/home.png) | [<img src="screenshot/delivery-details.png" width="220" alt="Delivery details showing the address, call button, due time, and cash to collect">](screenshot/delivery-details.png) | [<img src="screenshot/cash-validation.png" width="220" alt="Cash validation message showing the exact amount required to complete the delivery">](screenshot/cash-validation.png) |

## Start the API

Install Node.js 18+ and Flutter 3.44+ with the Android SDK, Android platform tools (`adb`), and JDK 17. Run `flutter doctor` to check the Android toolchain. Open a terminal at this project’s root and leave this command running.

```sh
node courier-server.js
```

The API listens on port 4000. Restarting it resets the deliveries.

## Run on Android

Run `flutter pub get` from the project root. Start an Android Studio emulator, or connect an Android phone by USB with USB debugging enabled and accept the debugging prompt. Check the device ID with `flutter devices`.

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

- The list should show 60 deliveries. Scroll to the bottom to find Oscar Reid, delivery #60.
- Open George Novak, delivery #7, to see the address and cash due. **Call customer** opens the Android dialer with the number filled in. Enter `262.49` and tap **Mark delivered** to see the cash validation, then enter `262.50` to complete it.
- Open Farah Bennett, delivery #6. **Mark delivered** records the handover without a cash entry. Return to the list to see the updated status and count.
- Stop the API and tap **Refresh deliveries** to check the connection error. Restart it and tap **Try again**.

The list uses the API’s run for today and displays due times in London time. Completion needs a connection in Step 1. If a request loses its response, tapping **Mark delivered** again in the same app session reuses the idempotency key for the same amount. Customer details are held in memory during use.

## Run the checks

```sh
flutter analyze
flutter test
```

The widget tests use a mock HTTP client, so the server and emulator can stay off for these checks.
