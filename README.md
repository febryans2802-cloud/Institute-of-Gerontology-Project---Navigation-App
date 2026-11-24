# Eyes-Free Navigation for Older Mobility-Cane Users

Research prototype (Institute of Gerontology) comparing **screen-based** and **audio + haptic** navigation guidance for older adults who walk with a mobility cane, on outdoor urban routes.

The study uses a **Wizard-of-Oz** setup: a researcher triggers prompts from a second phone, so the experiment tests the guidance modality rather than GPS accuracy.

- Study & system design: [`docs/study-design.md`](docs/study-design.md)
- UI flow (both phones, messages, failure paths): [`docs/ui-flow.html`](docs/ui-flow.html)
- App (Flutter, Android + iOS): [`app/`](app/README.md)
- Web demo (presentation only, not for data collection): [`demo/index.html`](demo/index.html). Open it in a browser; no build needed.

## Status
- Design: draft v0.2. One item is still open: the MoCA-T cutoff.
- App: wizard and participant roles, prompt delivery with acks, and logging are implemented and pass unit and loopback end-to-end tests. **Not yet built or tested on real phones** (Android or iPhone). The routes are templates and the prompt audio has not been recorded.
