# LSA Verification & Data Lineage Integration

HabotConnect HPF submission — `LsaVerificationScreen`.

## Architecture

Each file has one responsibility and depends only on the layer below it:

```
widgets/lsa_verification_screen.dart       → renders only, no logic
controllers/verification_controller.dart   → orchestrates, holds the ONLY mutable state
services/compliance_service.dart           → API + header injection + fail-closed gates
services/friction_logger.dart              → stall detection, knows nothing about API/UI
exceptions/lineage_exception.dart          → typed fail-closed signals
models/                                     → pure immutable data, no behavior
```

`LsaVerificationScreen` is a `StatelessWidget` (per §1). All dynamic state
lives in `VerificationController` (a `ChangeNotifier`), rebuilt via
`ListenableBuilder`; `HabotConnectApp` owns and disposes the one controller
instance. The controller also owns the `lsa_id` / `parent_consent_code`
`TextEditingController`s and the consent `FocusNode`, so a §3 Case 3 purge can
clear the visible fields and §4 focus tracking is direct.

### §1 fields

| Field | Type | Behaviour |
| ----- | ---- | --------- |
| `lsa_id` | Text Input · **prefilled** | editable, seeded `LSA-7049` |
| `parent_consent_code` | Text Input | user enters the code |
| `predecessor_id` | Hidden / **read-only** state | system id `PRED-9982-XYZ`, not editable |

Header title `LSA Onboarding Gate` + subtitle `HabotConnect Data Compliance`.
Button label is exactly `Verify & Submit`. Status banner shows one of
`Idle` / `Processing` / `Quarantined (Fail-Closed)` / `Success`.

## §2 — Request contract

`POST https://api.habotconnect.com/v1/compliance/verify`

| Header         | Value                                             |
| -------------- | ------------------------------------------------- |
| `Content-Type` | `application/json`                                |
| `x-trace-id`   | fresh UUID v4 per request                         |
| `x-logic-hash` | SHA-256 hex digest of the exact JSON body that is sent |

Body keys, in schema order: `predecessor_id`, `lsa_id`,
`parent_consent_code`, `timestamp_utc` — the timestamp is generated at send
time and trimmed to seconds precision (`2026-08-07T11:30:00Z`), matching the
§2B sample.

> The doc's literal `x-logic-hash` value is `SHA-256("")` (the empty-string
> digest) — treated as a format placeholder, like the sample `x-trace-id`.
> The header is computed per request; change one line in `ComplianceService`
> if an exact static value is required instead.

## §3 — Fail-closed logic

- **Case 1 — Valid submission** (`parent_consent_code = PCC-2026-9901`,
  `predecessor_id = PRED-9982-XYZ`): headers attached, request fires, a clean
  2xx carrying a non-null `status` → banner `Success`.
- **Case 2 — Missing lineage (orphan data)**: when `predecessor_id` is
  null/empty, `submit()` **throws `LineageException` before any network I/O**
  and before the `Processing` state — no socket is opened. Caught internally →
  banner `Quarantined (Fail-Closed)`. Per the spec this case does **not**
  purge or lock; the button stays enabled so lineage can be re-supplied.
- **Case 3 — Null API response / 500 / timeout** (`500` or `{"status": null}`):
  surfaces as `ComplianceQuarantineException`. The handler **instantly**
  `_purgeVolatileMemory()` (consent code + lineage id), `_resetFormState()`
  (consent cleared, `lsa_id` back to `LSA-7049`), **locks** the submit button
  (`submitEnabled: false`), and shows the exact text
  `Data Quarantined – Compliance Failure`. A **Reset session** action restores
  `Idle`.

## §4 — UI friction logging

`FrictionLogger` starts a 5-second timer when `parent_consent_code` gains
focus (via an explicit `FocusNode`), and restarts it on every keystroke / on
submit. If it fires uninterrupted it emits:

```
[UI_FRICTION_LOG] Timestamp: 2026-09-08T14:41:23Z | Field: parent_consent_code | Hesitation Duration: 5.0s
```

The default sink writes to **both debug and release** builds:

- `print(...)` → stdout / Android logcat (`flutter:` tag) / iOS console /
  browser console — not throttled, not stripped in release.
- `developer.log(..., name: 'UI_FRICTION_LOG')` → DevTools / IDE "Logging"
  view when a tool is attached.

`FrictionLogger(sink:)` is overridable so tests capture the line without
touching stdout.

### Watching it in release

```
flutter run --release            # line still prints to the terminal
flutter logs                      # or tail the device log separately
# Android:  adb logcat | grep UI_FRICTION_LOG
# iOS:      xcrun simctl spawn booted log stream | grep UI_FRICTION_LOG
```

## Tests

`flutter test` — 26 tests, no real network calls (`package:http/testing.dart`
`MockClient`, `package:fake_async`):

- `compliance_service_test.dart` (6) — header format, body schema + key order, timestamp format, all three cases
- `verification_controller_test.dart` (6) — Case 2 throws `LineageException` / no `Processing` / no purge; Case 3 purge + form reset + lock; recovery
- `fake_compliance_api_test.dart` (6) — the three cases end-to-end through the exact stack `flutter run` uses
- `friction_logger_test.dart` (3) — 5s threshold, keystroke reset, blur cancel
- `lsa_verification_screen_test.dart` (5) — render + editable/read-only fields, Case 1 → Success, Case 3 → locked + reset, §4 log fires / suppressed

## Running the three cases live

`api.habotconnect.com` is a mock host, so `flutter run` injects
`FakeComplianceApi` (an in-memory `http.Client`) and shows a small
**Demo triggers** panel:

| Case | How to trigger in the running app |
| ---- | --------------------------------- |
| **1 — Success** | `parent_consent_code` = `PCC-2026-9901`, then **Verify & Submit** |
| **2 — Missing lineage** | flip **Simulate orphan data** (clears `predecessor_id`), then submit — network is never called |
| **3 — Null / 500** | enter `PCC-FAIL-500` or `PCC-FAIL-NULL`, then submit — form clears, button locks, use **Reset session** to recover |
| **4 — Friction log** | focus `parent_consent_code`, wait 5s without typing — watch the console (debug *or* release) |

Hit the real endpoint instead with `flutter run --dart-define=LIVE_API=true`
(the demo panel is hidden in that mode).

```
flutter pub get
flutter analyze   # clean
flutter test      # 26 passing
flutter run
```

Verified locally with Flutter 3.35.2: `flutter analyze` reports no issues and
all 26 tests pass.
