# Study & System Design: Eyes-Free vs. Screen Navigation Guidance for Older Mobility-Cane Users

Status: **Draft v0.1** — open decisions are marked **[DECISION]**.

---

## 1. Research question

> For older adults walking with a mobility cane, does eyes-free guidance (audio + phone haptic) reduce navigation stops and gait disruption compared with screen-based guidance, without increasing navigation errors?

### Why this is not already answered
Eyes-free pedestrian navigation (audio, vibrotactile) has been studied extensively, mostly with younger sighted users or blind users. The gap this study targets is the **population** (older adults who use a cane for balance, with one hand occupied) and the **outcomes** (stops, gait stability, head-down time = safety-relevant), rather than only wayfinding accuracy.

### Hypotheses
- **H1 (primary):** Participants make fewer navigation-related stops (≥ 2 s) in the Audio+Haptic condition than in the Screen condition.
- **H2:** Head-down time is lower in Audio+Haptic.
- **H3:** Gait speed is higher and stride-time variability lower in Audio+Haptic.
- **H4 (exploratory):** Navigation errors (wrong turns, help requests) do not differ meaningfully between conditions. *With n ≈ 16–20 this cannot be a formal non-inferiority test; report descriptively with confidence intervals.*

---

## 2. Study design

**Within-subject, 2 conditions × 2 matched routes, fully counterbalanced.**

| Condition | Phone location | What delivers direction information | Attention cue |
|---|---|---|---|
| **S — Screen** | Held in the free (non-cane) hand | Large arrow + short text + landmark on screen | One generic short vibration when the instruction changes (no direction info) |
| **AH — Audio + Haptic** | Fixed pouch/pocket (see §2.2) | Pre-recorded Mandarin voice prompt + direction-specific vibration pattern | Included in the prompt |

### 2.1 Why the Screen condition gets a generic vibration — **[DECISION]**
Without any alert, Screen participants must watch the screen continuously, which makes the baseline artificially bad and the result trivially predictable. Giving both conditions the same *attention cue* means the conditions differ only in **which modality carries the direction information**. This is a cleaner contrast and matches how commercial apps behave (notification buzz).
Alternative: pure visual (no vibration) baseline — easier to "win" against, harder to defend in review.

### 2.2 Phone haptics: known weakness and mitigations
Phone vibration in a pocket is weaker and less distinct than a wrist-worn device, and vibrotactile sensitivity declines with age. Therefore in practice the AH condition will be **audio-dominant**; claims must be scoped to "audio + phone haptic".
Mitigations:
- **Fixed phone location** for all participants: a small chest/waist pouch on the non-cane side (trouser pockets vary too much by clothing). **[DECISION: pouch type]**
- **Few, maximally distinct patterns** (§5.4).
- **Perception check** during familiarisation: participant must correctly identify ≥ 90 % of patterns *while walking*; otherwise note it and still run (report as covariate).
- Smartwatch (Garmin Connect IQ) haptics → future work.

### 2.3 Audio output — **[DECISION]**
Phone speaker inside a pouch + Tainan street noise = likely inaudible. Options:
1. **Open-ear bone-conduction headset** (recommended: keeps traffic audible, no ear occlusion).
2. Single earbud on the non-traffic side.
3. Phone speaker only (most ecological, highest risk of missed prompts).

Whatever is chosen, use the same device for all participants, and run a hearing check of the prompts at the start location.

### 2.4 Counterbalancing
4 sequences (condition order × route assignment):

| Seq | 1st | 2nd |
|---|---|---|
| A | S on Route 1 | AH on Route 2 |
| B | AH on Route 1 | S on Route 2 |
| C | S on Route 2 | AH on Route 1 |
| D | AH on Route 2 | S on Route 1 |

Assign participants in blocks of 4 → **n = 16 or 20**.

### 2.5 Sample size
For a within-subject comparison with α = .05 and power = .80: d_z = 0.8 → n ≈ 15; d_z = 0.7 → n ≈ 19. Target **n = 20** (allows ~4 dropouts down to 16 while keeping balanced sequences only if dropouts are replaced). This is powered for **medium-to-large** effects only — state this in the limitations.

---

## 3. Participants

### Inclusion
- Age ≥ 65.
- Uses a single-point or quad cane for outdoor walking for ≥ 3 months.
- Able to walk ≥ 500 m outdoors with the cane, with rests allowed.
- Able to hear the prompts at normal volume (with hearing aids if usually worn) — verified at session start.
- Able to read the screen text at arm's length (with usual glasses).
- Cognitive screening: MoCA-Taiwan above the education-adjusted cutoff. **[DECISION: cutoff, with advisor]**

### Exclusion
- Injurious fall in the past 3 months.
- Unstable cardiovascular/respiratory condition, or physician advice against outdoor walking.
- Uncorrectable severe hearing or visual impairment.
- Familiarity with the study routes beyond "occasionally passed through" (to limit route knowledge effects) — record a familiarity rating regardless.

### Covariates to record
Age, sex, education, cane type and years of use, fall history (12 months), smartphone experience, Timed Up and Go (TUG), hearing aid use, glasses type (**bifocal/progressive lenses** matter: looking down through them while walking is itself a fall risk), route familiarity.

> Recruitment: community care centres (社區關懷據點), senior learning centres, NCKU Hospital outpatient departments. Coordinate with the Institute of Gerontology.

---

## 4. Routes and procedure

### 4.1 Routes
- Two routes, each **~400–600 m**, **6–8 decision points**, at most **1 signalised crossing** each.
- Matched on: length, number of turns (left/right balanced), crossings, surface/slope, and arcade (騎樓) segments.
- Must start and end at places with seating and shade.
- Walk and document each route (photos, measured distances, hazards) **before** submitting the ethics application — the IRB will ask.
- Pilot with 2–3 people (ideally older adults) to confirm matched completion times.

### 4.2 Staff (minimum 2)
- **Wizard/observer:** walks 3–8 m behind, triggers prompts, logs observed events in the wizard app, wears a chest camera.
- **Safety spotter:** walks beside the participant on the traffic side; **does not give directions**; intervenes only for safety. Script the spotter's allowed phrases.

### 4.3 Session (~90 min)
1. Consent, screening, covariates, TUG (15 min).
2. Fit equipment: IMU at lower back, pouch, headset. Clock sync (§6.4). (10 min)
3. Familiarisation on a short practice route (~100 m) with **both** conditions, including the haptic perception check. (10 min)
4. Condition 1 route walk (~10–15 min) → seated rest, Borg RPE, NASA-TLX, short questions. (10 min)
5. Rest ≥ 5 min or until the participant reports being ready.
6. Condition 2 route walk → same questionnaires.
7. Preference + semi-structured interview. (10 min)

### 4.4 Stop/withdrawal rules
Dizziness, chest pain, shortness of breath, Borg RPE ≥ 15, near-fall, participant request, rain/heat warning (check the heat index; schedule morning sessions in summer).

---

## 5. Prompts

### 5.1 Prompt structure
Each decision point has two prompts, triggered by the wizard:
- **Advance** (~15–20 m before): "前方路口，左轉" / "Ahead at the intersection, turn left"
- **Execute** (at the turn): "現在左轉，經過全家便利商店" / "Turn left now, past the FamilyMart"

Plus: **Continue straight** reassurance (on long segments), **Arrived**, **Off-route** ("請停下，工作人員會協助您" / "Please stop, staff will assist you").

### 5.2 Wording rules
- Landmark-based, not meter-based.
- ≤ 8 Chinese characters before the key verb; key information (left/right) early.
- Pre-recorded by one speaker at a slow rate (consistency across participants; avoids TTS variability). Taiwanese Hokkien version optional. **[DECISION]**

### 5.3 Screen design (Condition S)
- One instruction at a time; large arrow (≥ 40 % of screen height), text ≥ 24 pt, high contrast, landmark text below.
- No map (a map invites prolonged looking and adds a confound). **[DECISION: no map vs. simple map]**
- Same content and same trigger timing as AH prompts.

### 5.4 Vibration patterns (Condition AH)
Kept to four, rhythmically distinct, each preceding the audio:

| Meaning | Pattern (ms on/off) |
|---|---|
| Turn left | 2 long: 400-200-400 |
| Turn right | 4 short: 100-100-100-100-100-100-100 |
| Continue / reassurance | 1 short: 150 |
| Arrived | 1 very long: 1000 |
| Screen-condition generic cue | 1 short: 150 |

Use the Android amplitude API at maximum amplitude where supported. Validate during piloting.

---

## 6. Measures

| Type | Measure | Source | Operational definition |
|---|---|---|---|
| Primary | Navigation stops | IMU, verified by video | Walking speed < 0.1 m/s for ≥ 2 s, not at a signal crossing |
| Primary | Navigation errors | Wizard log + video | Wrong turn (> 5 m into a wrong branch), help request, staff intervention for direction |
| Secondary | Head-down time | Chest-camera video | % of walking time with the head pitched down toward the phone; 2 coders, Cohen's κ on ≥ 20 % of videos |
| Secondary | Gait speed | IMU + measured route length | Route length / walking time excluding signal waits |
| Secondary | Stride-time variability | IMU | Coefficient of variation of stride time on straight segments |
| Secondary | Completion time | App logs | Start to arrival |
| Subjective | Exertion | Borg RPE (6–20) | After each route |
| Subjective | Workload | NASA-TLX raw, simplified Chinese wording | After each route |
| Subjective | Perceived safety, confidence | 5-point items | After each route |
| Subjective | Preference + reasons | Interview | End of session |
| Technical | Prompt latency | App logs | `prompt_sent` → `prompt_rendered` (clock-corrected) |

### 6.1 Analysis plan
- Count outcomes (stops, errors): generalised linear mixed model (Poisson or negative binomial) with fixed effects **condition, order, route** and a random intercept for participant.
- Continuous outcomes: linear mixed model with the same structure.
- Check order × condition interaction (carry-over).
- Report effect sizes and 95 % CIs; Wilcoxon signed-rank as a sensitivity check.
- Qualitative: thematic analysis of interviews.
- **Pre-register** hypotheses and the primary outcome (e.g., OSF) before data collection.

---

## 7. System design

### 7.1 Overview

```
┌────────────────────────┐   Wi-Fi hotspot (wizard phone)   ┌──────────────────────────┐
│  WIZARD APP (Android)  │ ───── WebSocket, JSON msgs ────▶ │ PARTICIPANT APP (Android)│
│  - hosts hotspot+server│ ◀──── acks / heartbeat ───────── │ - renders prompt by      │
│  - route script UI     │                                  │   condition (S / AH)     │
│  - observer event log  │                                  │ - logs render times, GPS │
│  - JSONL log           │                                  │ - JSONL log              │
└────────────────────────┘                                  └──────────────────────────┘
          ▲                                                              
          │ shared clock-sync marker                                     
┌─────────┴─────────┐   ┌──────────────────────┐
│ IMU at lower back │   │ Chest camera (video) │
│ (2nd phone running│   │ worn by wizard       │
│ sensor-logger app │   └──────────────────────┘
│ or dedicated IMU) │
└───────────────────┘
```

- **One codebase, two roles** (selected at launch): `wizard` and `participant`.
- **Transport:** the wizard phone runs a mobile hotspot and a WebSocket server; the participant phone joins it. This works without mobile data, has low latency, and is reliable within the 3–8 m following distance. Fallback: auto-reconnect plus heartbeat every 1 s; the wizard UI shows connection status and the last ack.
- **No GPS-based triggering** in the main study (Wizard-of-Oz). GPS is logged only, for trajectory plots and post-hoc checks.

### 7.2 Framework — **[DECISION]**
Recommended: **Flutter (Android only)**. It has good support for WebSocket servers (`dart:io`), the vibration amplitude API, audio playback, and screen keep-awake. React Native is also viable if the team already knows it.

### 7.3 Route script (JSON)

```json
{
  "route_id": "R1",
  "name": "NCKU east gate → ...",
  "prompts": [
    {
      "id": "R1-P01-ADV",
      "decision_point": 1,
      "kind": "advance",
      "direction": "left",
      "text_zh": "前方路口，左轉",
      "landmark_zh": "全家便利商店",
      "audio_file": "R1-P01-ADV.m4a",
      "vibration": "left"
    }
  ]
}
```

The wizard UI walks through `prompts` in order: a large **NEXT** button sends the next prompt, plus **REPEAT** and **OFF-ROUTE**.

### 7.4 Wizard observer buttons
`stop_observed`, `wrong_turn`, `help_request`, `spotter_intervention`, `near_fall`, `signal_wait_start/end`, `free_note` (voice memo), with **undo** for the last event. All events are timestamped.

### 7.5 Log schema (JSONL, one event per line, on each device)

```json
{
  "session_id": "S007",
  "participant_id": "P07",
  "device_role": "participant",
  "condition": "AH",
  "route_id": "R2",
  "seq": 1532,
  "t_mono_ms": 8123456,
  "t_wall": "2026-12-03T09:14:22.418+08:00",
  "clock_offset_ms": -37,
  "event": "prompt_rendered",
  "data": { "prompt_id": "R2-P03-EXE", "channel": "audio", "audio_start_ms": 8123460 }
}
```

Event types:
- **Session:** `session_start`, `condition_start`, `condition_end`, `session_end`.
- **Sync:** `clock_sync` (offset/RTT), `sync_marker`.
- **Prompts:** `prompt_sent` (wizard), `prompt_received`, `prompt_rendered` (per channel: `screen` / `audio` / `vibration`), `prompt_ack`.
- **Sensors:** `gps_fix` (1 Hz, lat/lon/accuracy).
- **Observer:** events from §7.4.
- **Health:** `connection_lost`, `connection_restored`, `error`.

Logs are stored locally and exported over USB/share sheet after the session. Use **participant codes only, no names**, in the logs.

### 7.6 Clock synchronisation
- **App ↔ app:** NTP-style ping exchange over the WebSocket at connect and every 30 s; log the offset.
- **IMU and video:** at the start and end of each route, the wizard presses `sync_marker`. This makes the participant phone flash and vibrate while the researcher taps the IMU device 3 times in view of the camera. Align all streams on these markers.

### 7.7 Proposed repo layout
```
/app            Flutter app (wizard + participant roles)
/routes         route scripts (JSON) + prompt audio
/analysis       Python: log parsing, IMU gait features, stats
/docs           this document, protocol, consent forms, IRB materials
```

---

## 8. Ethics and data
- IRB application must include: the route documentation, safety protocol (§4.2, §4.4), spotter script, insurance, data management plan, and video consent (bystanders in public space: blur faces in any published frames).
- Store video and logs encrypted; keep the participant-ID key separate.

---

## 9. Open decisions (summary)
1. Generic vibration cue in the Screen condition (recommended: yes) — §2.1
2. Phone pouch type/location — §2.2
3. Audio device: bone-conduction (recommended) / single earbud / speaker — §2.3
4. MoCA-T cutoff — §3
5. Hokkien prompts — §5.2
6. Screen with or without a map (recommended: no map) — §5.3
7. Flutter (recommended) vs. React Native — §7.2
8. IMU: second phone + logger app vs. dedicated sensor — §7.1

---

## 10. Limitations to state up front
- Phone haptics are weaker than wrist haptics → AH is audio-dominant.
- Wizard-of-Oz timing may be more consistent than real GPS triggering → results show the upper bound of what the guidance mode can achieve.
- Powered only for medium-to-large effects.
- Two routes in one city area; findings may not generalise to other urban forms.
- Short single-session exposure; there is a novelty effect and no long-term learning.
