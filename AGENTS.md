# AGENTS.md

Scope: This file guides AI coding agents working in this repository.

## Fast Start
- Install deps: `flutter pub get`
- Analyze: `flutter analyze`
- Run app: `flutter run`
- Run tests: `flutter test`
- Build APK: `flutter build apk`

## Project Shape
- App entry and providers wiring: [lib/main.dart](lib/main.dart)
- Admin and teacher flows: [lib/screens/admin](lib/screens/admin)
- Shared rendering and utilities: [lib/screens/shared](lib/screens/shared)
- State management: [lib/providers](lib/providers)
- API and OCR integration: [lib/services](lib/services)

## Core Rules
- Keep changes surgical. Do not rewrite stable admin flows.
- Preserve provider wiring in [lib/main.dart](lib/main.dart) when adding new state.
- Do not hardcode API hosts; use [lib/utils/constants.dart](lib/utils/constants.dart).
- Maintain resource cleanup discipline for timers, subscriptions, and controllers.
- Keep Android ABI filters and Gradle stability settings unless the task explicitly requires changing them.

## Known Pitfalls
- LaTeX and WebView rendering changes require careful manual verification.
- Resource leaks commonly come from missing dispose cleanup in stateful widgets/providers.
- Test coverage exists but is minimal; add focused tests for non-trivial logic.
- Local environment differences can affect analysis and Gradle behavior.

## Read Before Large Changes
- Existing repo guidance: [GEMINI.md](GEMINI.md)
- Resource lifecycle guidance: [RESOURCE_CLEANUP_GUIDE.md](RESOURCE_CLEANUP_GUIDE.md)
- Lint setup: [analysis_options.yaml](analysis_options.yaml)
- Dependency and toolchain config: [pubspec.yaml](pubspec.yaml)

## Custom Agents
- Specialized test-system auditor: [.github/agents/TEST-SYSTEM-ARCHITECT.agent.md](.github/agents/TEST-SYSTEM-ARCHITECT.agent.md)

## Output Expectations For Agents
- State scope and assumptions first.
- Provide a concise risk list before implementing broad changes.
- Include validation evidence and follow-up tasks.
