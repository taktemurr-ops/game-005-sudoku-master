# Sudoku Master — Game Studio 100 / Game 005

Flutter offline Sudoku for Android/iOS. This update extends the **existing**
private repository, preserving independently developed monetization policy
modules and their tests. This is not a new repository.

## Game functionality

Five difficulty/day modes, deterministic daily seed, shuffled solved boards,
unique-solution puzzle creation, 9×9 touch input, row/column/box highlighting,
undo, erasable guesses, pencil notes, legal candidate autofill, free logical
hint, optional reveal, mistake limit, pause, timer, statistics and best times.
Auto-save/restore, local data erasure, contrast, haptic setting, TR/EN/AR UI
and semantic cell descriptions. No account or Internet required.

## Development

```bash
flutter create --platforms=android,ios --project-name game_005_sudoku_master .
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
```

GitHub Actions covers Flutter quality and Android debug APK; an optional
workflow checks unsigned Android AAB and iOS compilation. Passing CI does not
substitute physical-device testing, App Store signing or store approval.

## Monetization and privacy

No ad SDK, purchase screen, tracking or account collection in the gameplay UI.
The pre-existing monetization policy modules are retained for later integration
but are not wired to real advertising/billing. A functioning purchase flow must
not be represented as complete without verified store/backend infrastructure.

See `docs/RELEASE_READINESS.md` and the repository's `/issues/1` for acceptance.
