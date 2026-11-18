# Prompt audio

Put pre-recorded prompts here, named exactly as `audio_file` in
`assets/routes/*.json` (plus `OFF_ROUTE.m4a`).

- One speaker for all prompts, slow rate, recorded in a quiet room.
- Normalise loudness across files (e.g. -16 LUFS).
- If a file is missing, the app falls back to on-device Mandarin (zh-TW) TTS
  and logs `"source": "tts"` in `prompt_finished`, so you can verify that no
  real session used TTS by accident.
