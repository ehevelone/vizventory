# Vizventory Mobile

Mobile capture app for the Vizventory desktop intake screen.

## Current Flow

1. Start the desktop site from `C:\Vizventory`.
2. Run this Flutter app.
3. Open Settings and connect to the desktop by scanning the desktop QR or entering the server address.
4. Use Inventory to browse current items.
5. Use Add to take/select pictures and save new inventory items.
6. Use Scan to scan item labels and check items in or out.

The app remembers recent desktops, so repeat connections can be selected from remembered devices.

## Run

```powershell
cd C:\Vizventory\mobile_app
flutter pub get
flutter run
```

The desktop server address must be reachable from the phone or emulator. On a
real phone, scan the QR generated from the computer's Wi-Fi/LAN address, not
`localhost`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
