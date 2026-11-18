# Cane Nav Study app (Flutter, Android)

One app with two roles, installed on two phones:

| Role | Carried by | Does |
|---|---|---|
| **Wizard (研究人員)** | Researcher walking 3–8 m behind | Hosts the Wi-Fi hotspot, sends the scripted prompts (NEXT / REPEAT / OFF-ROUTE / SYNC), logs observer events |
| **Participant (受試者)** | Participant | Shows the prompt (Screen) or vibrates and speaks it (Audio + Haptic), logs GPS and render times |

The design rationale is in [`../docs/study-design.md`](../docs/study-design.md).

## Build and install

Requirements: Flutter **3.50+** (stable) and the Android SDK (via Android Studio).

```bash
cd app
flutter pub get
flutter test                 # unit + loopback end-to-end tests
flutter build apk --release  # → build/app/outputs/flutter-apk/app-release.apk
```

Install the same APK on both phones (`adb install -r app-release.apk`).
The release build uses the debug signing key. That is fine for a research
prototype that is not distributed through a store.

## Field setup (each session)

1. **Wizard phone:** turn on the mobile hotspot. Keep mobile data ON. Otherwise
   some Android versions show "no internet" warnings and the participant phone
   may leave the hotspot.
2. **Participant phone:** join the hotspot. If Android asks
   "This network has no internet access. Stay connected?", choose **Yes**.
   Then pair the bone-conduction headset, set media volume, and enable
   location.
3. Open the app on both phones: **Wizard** on one, **Participant** on the other.
   The participant phone usually finds the wizard automatically. If not, type
   the IP shown on the wizard screen.
4. Wizard: enter the **participant code** (never a name) and the enrolment
   number. The counterbalancing sequence A–D is suggested from that number.
   Then press **Start session**.
5. Check that the wizard status bar is green (**CONNECTED**) and that RTT is
   under ~100 ms.
6. Run **Practice S** and **Practice AH** on the practice route, including the
   vibration-pattern recognition check.
7. Run **Block 1** then **Block 2**. At the start and end of each route, press
   **SYNC** while the camera can see the participant phone (white flash) and
   tap the IMU phone 3 times on camera.
8. **End session** (top right). The participant phone shows 完成.
9. Export logs from **Logs** on both phones, or copy over USB from
   `Android/data/org.navstudy.cane_nav/files/logs/`.

### During a route
- **NEXT** sends the next scripted prompt. The big button always shows which
  prompt comes next.
- If the red **NOT RECEIVED** banner appears, press **REPEAT**.
- The observer buttons log timestamped events. **Undo** retracts the last one
  (it is logged as retracted, never deleted).
- To leave the participant screen, long-press the small status dot in the
  top-left corner, then confirm. There are no other touch targets, so touches
  inside the pouch do nothing.

## Before real data collection

- [ ] Replace `assets/routes/R1.json` and `R2.json` (currently **templates**,
      flagged with a warning on the wizard screen) with the surveyed routes.
- [ ] Record the prompt audio into `assets/audio/` (see the README there).
      Until then the app uses Mandarin TTS, logged as `"source": "tts"`.
- [ ] Pilot on the real routes. Check prompt latency (`prompt_ack.latency_ms`),
      GPS log quality, and whether the vibration patterns can be felt through
      the pouch.
- [ ] Test on the exact phone models you will use. Vibration strength and
      amplitude support vary a lot between models.

## Code map

```
lib/
  core/        study design (conditions, sequences), route scripts, vibration
               patterns, protocol, clock sync, JSONL event logger
  net/         WebSocket server (wizard), client (participant), UDP discovery
  wizard/      WizardSession (logic) + setup/run screens
  participant/ ParticipantSession (logic), device outputs (vibration, audio,
               TTS, GPS) + setup/run screens
  shared/      log storage and export
test/
  core_test.dart   unit tests
  link_test.dart   end-to-end: real server + client over loopback, both
                   conditions, acks, latency, reconnect, unacked warning, logs
```

## Log format

There is one JSONL file per device per session, e.g. `P07_20261203_0914_wizard.jsonl`.
Every line has `session_id, participant_id, device_role, condition, route_id,
seq, t_mono_ms, t_wall_ms, t_wall, clock_offset_ms, event, data`.
`clock_offset_ms` = participant clock − wizard clock. Subtract it from
participant `t_wall_ms` to put both logs on the wizard's timeline.
