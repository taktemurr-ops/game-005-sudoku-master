# Game 005 — Acceptance gates (must be proven before store release)

## Source implemented
- Uniquely solvable seeded generator: easy, medium, hard, expert and daily.
- Pure Dart Sudoku rules, candidates, free logical hint, reveal hint,
  notes/auto-pencil, undo, mistake tracking, restart and solved detection.
- Play, main menu, pause, victory, failure, settings, statistics.
- Autosave on input/background, resumed game, corrupt-save handling and full
  game-owned local data wipe. No third-party account or internet dependency.
- TR/EN/AR text, RTL semantics, contrast setting and accessible grid labels.
- Tests for rules, generator uniqueness, save integrity, persistence and UI.
- Android debug and optional Android/iOS unsigned release GitHub Actions files.

## External release gates — NOT automatically satisfied by source code
- Complete successful GitHub Actions analysis/tests AND Android debug/AAB builds.
- iOS macOS unsigned compile; separate Xcode signing and physical device test.
- Android emulator/physical device landscape/tablet/accessibility QA.
- Final original assets, font/icon/screenshot licensing and polished store copy.
- Store metadata, privacy policy, age rating, SDK privacy manifest and consent.
- Production ads/IAP intentionally **not enabled**; if later introduced, require
  real store/server receipt verification, parental/age rules, purchase recovery,
  explicit privacy consent and regression tests.
- Crash/performance monitoring after user consent and privacy review.

Keep /issues/1 open until all evidence exists. A pushed code package is NOT a
verified production release.
