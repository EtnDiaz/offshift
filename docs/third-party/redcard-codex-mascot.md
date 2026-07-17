# Red Card Codex mascot provenance

Offshift packages six adapted sleeping frames for the local black care screen:
`sleeping-01.png` through `sleeping-06.png`, plus a user-selected front-facing
sleeping Codex brand mark at `brand/sleeping-codex-logo.png` for Today, and a
derived `Resources/AppIcon/Offshift.icns` plus the compiled `AppIcon` asset
catalog for the local macOS app bundle.

- Upstream: `https://github.com/openai/redcard`
- Source revision: `7425e60c469c51960367bfe8b4608781a548220c`
- Source paths: `assets/sprites/waiting/`
- License: Apache License 2.0; copy bundled at
  `offshift_companion/Sources/OffshiftCompanion/Resources/ThirdParty/RedCard/LICENSE-APACHE-2.0.txt`
- Notice: upstream `NOTICE` is bundled beside the frames.
- Adaptation: the product owner supplied a six-panel sleeping-Codex sheet on
  2026-07-17. Offshift removes its magenta chroma-key background and panel
  borders, retaining the six supplied poses as local PNG frames. No audio asset
  was imported.
- Brand mark and app icon: the product owner supplied a high-detail
  sleeping-Codex image on 2026-07-17 and selected it as the Offshift logo.
  `script/generate_app_icon.sh` renders the standard macOS `.icns` and
  `AppIcon.appiconset` sizes from that mark without changing its artwork;
  `build_and_run.sh` compiles the catalog with Apple `actool`. The bundled
  asset removes only the magenta chroma-key background; it is local-only and
  is not sent to ChatGPT, MCP, the Worker, or Home Assistant.

## Public redistribution conditions

The upstream Apache License 2.0 grants permission to reproduce, adapt, and
redistribute these character assets. Offshift may therefore include the adapted
frames and mark in its public repository, release, video, and Devpost material
when all of the following are true:

1. The bundled Apache-2.0 license and upstream `NOTICE` remain distributed
   with the asset, including in the macOS app bundle/DMG.
2. This provenance file and any release notes say that Offshift modified the
   source art for a sleeping care-screen animation.
3. The separately attributed `assets/referee-whistle.wav` is never copied or
   used.
4. The application is not named, presented, or marketed as an official OpenAI
   or Codex product, and it does not imply endorsement. `OpenAI` and `Codex`
   appear only where reasonably needed to describe the upstream source.

This is a project compliance policy based on the bundled upstream license and
notice, not a claim of trademark permission or legal advice. See ADR 0023.
