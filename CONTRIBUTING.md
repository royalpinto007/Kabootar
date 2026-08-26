# Contributing to Kabootar

Thanks for your interest. Kabootar is a small, focused codebase and the bar for
changes is that they keep the layering clean and the mesh engine provable.

## Ground rules

- **Keep the engine pure.** `lib/core/mesh` must never import Flutter, the
  transport plugin, or SQLite. If the engine needs something from the outside
  world, add a narrow port (interface) and inject it. This is what keeps the
  routing logic testable on a laptop.
- **Every routing change needs a test.** Add or extend a scenario in both
  `tool/engine_check.dart` and `test/mesh_engine_test.dart`.
- **Prose uses plain hyphens, not em-dashes.**

## Local checks

No device needed to validate the core:

```bash
dart run tool/engine_check.dart     # 32 routing invariants, plain Dart
```

With Flutter installed:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

`dart format` is the formatting authority. CI fails if a Dart file would be
changed, so run the same check locally before pushing.

## Running the app

See [docs/PLATFORM_SETUP.md](docs/PLATFORM_SETUP.md). You need two physical
devices of the same OS family (Android⇄Android or iOS⇄iOS) to see delivery -
emulators have no real Bluetooth/Wi-Fi radio.

## Commit style

Conventional-commit prefixes (`feat:`, `fix:`, `test:`, `docs:`, `chore:`),
present tense, explain the *why* in the body when it is not obvious.

## Where things live

| Path | Responsibility |
|------|----------------|
| `lib/core/mesh` | DTN routing engine, envelope, config, ports (pure Dart) |
| `lib/core/models` | domain models (Message, Contact, Identity) |
| `lib/data` | SQLite persistence + identity store |
| `lib/transport` | transport interface + Nearby/Multipeer implementation |
| `lib/services` | `ChatService` - the seam tying it all together |
| `lib/ui` | Material 3 screens and widgets |
| `tool/` | dependency-free engine verification |
| `test/` | flutter_test suites |

## Claiming an issue

Want to pick something up? Just comment on the issue saying you'd like to work on
it. A workflow adds the `claimed` label so nobody else duplicates your effort.

Two small rules keep things fair:

- **Two open claims per person.** If you already hold two claimed issues, we'll ask
  you to finish one first so other people get a turn. Comment again once one lands
  and the next is yours.
- **Claims go stale after 14 days.** If a claimed issue sees no activity for two
  weeks, the label is removed and it goes back in the pool. No hard feelings, and
  you can always claim it again.

Link your pull request to the issue in the PR description (for example
`Closes #12`). When that PR is merged the issue closes itself, and if the PR is
closed without being merged the claim is released so someone else can pick it up.

No pressure on timelines otherwise. Ask questions in the issue thread any time.
