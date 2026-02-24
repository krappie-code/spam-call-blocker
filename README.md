# 📱 Spam Call Blocker

A local-first Android spam call blocker built with Flutter. Screens unknown callers with a challenge-response system — callers must press a random digit to connect. No data leaves your device.

## Features

- **Challenge-Response Screening** — Unknown callers hear a TTS prompt: "Press [0-9] to connect." Bots and robocallers can't pass.
- **Contact Auto-Whitelist** — Calls from your phone contacts are always allowed through.
- **Block List Management** — Manually block numbers or auto-block based on spam feedback.
- **Post-Call Feedback** — After calls from unknown numbers, the app asks "Was this spam?" to learn over time.
- **Export/Import Block Lists** — Share block lists as JSON files with family or friends.
- **POPIA Compliant** — All data stored locally on device. Zero external data transmission.
- **Material 3 Design** — Clean, modern UI with dark mode support.

## Architecture

```
lib/
├── main.dart                           # App entry point
├── models/
│   ├── call_log.dart                   # Call log entry model
│   ├── block_list.dart                 # Block list entry model
│   └── settings.dart                   # App settings model
├── services/
│   ├── call_screening_service.dart     # Android CallScreeningService bridge (API 29+)
│   ├── incall_service.dart             # InCallService fallback bridge (API 26-28)
│   ├── challenge_service.dart          # TTS challenge-response logic
│   ├── contacts_service.dart           # Phone contacts sync
│   └── database_service.dart           # SQLite local database
└── ui/
    ├── home_screen.dart                # Dashboard with stats
    ├── call_history_screen.dart        # Call log with spam feedback
    └── settings_screen.dart            # Settings & data export/import
```

## Android Integration

| API Level | Mechanism | Notes |
|-----------|-----------|-------|
| 29+ (Android 10+) | `CallScreeningService` | Full call screening with system role |
| 26-28 (Android 8-9) | `InCallService` | Fallback with basic call control |

Native Kotlin services:
- `SpamCallScreeningService` — Handles call screening callbacks from the system
- `SpamInCallService` — Fallback for pre-Android 10 devices
- `MainActivity` — Platform channel bridge for role management

## Requirements

- **Min SDK:** Android 8.0 (API 26)
- **Target SDK:** Android 14 (API 34)
- **Flutter:** 3.0+

## Permissions

| Permission | Purpose |
|-----------|---------|
| `READ_PHONE_STATE` | Detect incoming calls |
| `READ_CALL_LOG` | Access call history |
| `ANSWER_PHONE_CALLS` | Answer calls after challenge passes |
| `READ_CONTACTS` | Auto-whitelist phone contacts |
| `CALL_PHONE` | Call management |
| `MANAGE_OWN_CALLS` | Self-managed call handling |

## Getting Started

```bash
# Clone the repo
git clone https://github.com/krappie-code/spam-call-blocker.git
cd spam-call-blocker

# Get dependencies
flutter pub get

# Run on connected device
flutter run
```

## Privacy

This app is designed with privacy as a core principle:
- **No analytics** — Zero tracking or telemetry
- **No network calls** — The app never phones home
- **Local SQLite** — All data lives on your device
- **POPIA compliant** — Meets South African data protection requirements
- **Export control** — You decide when and how to share your data

## Tech Stack

- [Flutter](https://flutter.dev) with Material 3
- [sqflite](https://pub.dev/packages/sqflite) — Local SQLite database
- [flutter_tts](https://pub.dev/packages/flutter_tts) — Text-to-speech for challenges
- [permission_handler](https://pub.dev/packages/permission_handler) — Runtime permissions
- [contacts_service](https://pub.dev/packages/contacts_service) — Phone contacts access
- [share_plus](https://pub.dev/packages/share_plus) — Block list sharing
- [file_picker](https://pub.dev/packages/file_picker) — Block list import
- [provider](https://pub.dev/packages/provider) — State management

## License

MIT
