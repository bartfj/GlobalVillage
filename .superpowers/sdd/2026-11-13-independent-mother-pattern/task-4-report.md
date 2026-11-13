# Task 4 integration report

## Result and scope

Implemented on `codex/independent-mother-pattern`, starting at `e11ea1a`. User-approved integration plus root-approved package-layout and new Chinese transfer-scene corrections are complete. Final checks below have exit 0. Full client validation, APK release and sharing remain root-owned.

- Registered `course/motherPattern` in the client cache asset catalog and server publication catalog. A real ContentCache manifest download test verifies registration reaches the loader.
- Added the dependency-free `mother_pattern_schema` package at `server/schema`. Both client and server import the same package URI. The client depends on `server/schema`, server on `schema`; locks add only this local package. No shelf/postgres/server runtime dependency enters the client.
- Shared validation rejects wrong course identity; ordinary-course unit/lesson/scored exercise IDs in the reserved `mp_` namespace; ordinary-course independent metadata; malformed independent shape, 4-unit/16-lesson schedule, ordered taught pattern IDs, unknown/future dialogue references, metadata, phase types/counts/references/order, duplicate IDs and unsafe/misplaced audio. Scored/supplemental `audioId == id` is the same entity alias; instructional dialogue/vocabulary audio IDs participate separately in the global entity set.
- Independent scored/example/review `sentence` must normalize to canonical `answer`; chunks must reconstruct the answer; choices must be distinct and include the target. Authored contraction/other acceptedAnswers may differ from canonical. This rule does not change ordinary fillBlank or other old exercise contracts.
- CourseLoader rejects invalid overlays, drops their cached pack and falls back to its bundled asset. Valid cached legacy patternTraining remains parseable and never becomes patternLesson. Task3 already removed every legacy entry/UI hook; no Task3 UI/model/store/audio code was modified.
- Removed only the six injected patternTraining fields from course_beginner.json. The regression reads `git show d691041:assets/courses/course_beginner.json`, removes exactly u1l2/u4l1/u4l3/u4l4/u9l1/u9l2 metadata and compares all structured JSON against the current file. Original exercises/IDs/other JSON are preserved. Legacy actual JSON remains parseable and old audio files remain present.
- Retired generate_pattern_pilot CLI without writing files. Its exported withPatternPilot API remains a nonmutating deep-copy compatibility entry point, including refresh calls. Expansion reruns no longer require/inject pilot content.
- Backup badge whitelist adds mp_ unit/lesson IDs only. v1/v2 fields are unchanged. Tests round-trip new progress and badges, preserve old formats/account behavior, and show local motherPattern reviews/events are absent from backup and are not imported.
- Admin motherPattern editing uses raw JSON and saves the complete object, preserving metadata/audioId/speakingMode. Existing ordinary form edits still modify objects in place and preserve unknown keys. A Node VM test executes the actual served JavaScript with a minimal DOM boundary.
- Audit includes all new scored/examples/reviews/dialogue/vocabulary clips; accepts --output to keep release documents root-owned. Content validation includes the new pack and checks IDs/targets. Exact old course enumeration now includes motherPattern; deterministic old expansion compares parsed JSON and normalized authored Markdown line endings and excludes the independent generator.

## Approved scene audit

Root expanded scope to `tool/generate_mother_pattern_course.dart`, `assets/courses/course_mother_pattern.json`, and `test/mother_pattern_content_test.dart` after finding final scenario tasks repeated earlier chunks/input situations.

Added a first failing test comparing normalized scenario prompts with each lesson's first eight tasks, one another and four extra review scenes. Replaced only 24 Chinese e9/e10 prompts across the twelve pattern lessons with genuinely new people/places/tasks (competition teammate, excursion driver, swimming registration, hotel reception, charity sorting, campus stall, bank counter, etc.). Required role/object/quantity/intent and all canonical/accepted English answers remain identical. The four integrated dialogue lessons were unchanged. Generator and new JSON are synchronized; --check passes.

Before/after audio exports each contain exactly **483 identical ID/text pairs** (160 scored, 36 examples, 48 review, 73 dialogue, 166 vocabulary). The captured before/after --audio-manifest outputs have identical SHA256 `FC17370A4272B56CD46CF8035EC9C972A4AF4412018F4AD370F40C39998503B4` (PowerShell output snapshot encoding). Total scored count remains 160. No MP3/WAV/manifest/model field changed and no audio regeneration is needed.

## Red verification

All commands use `PUB_CACHE=D:/fv_sdk/pub-cache`; cwd is the worktree root unless noted. Logs are under `.superpowers/sdd/2026-11-13-independent-mother-pattern/`.

1. `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe D:/fv_sdk/flutter/bin/cache/flutter_tools.snapshot test --no-pub --concurrency=2 --reporter=expanded test/mother_pattern_overlay_test.dart test/backup_service_test.dart test/pattern_content_test.dart test/pattern_training_model_test.dart test/course_expansion_test.dart`
   - task-4-client-red.log: **60 passed / 30 failed / exit 1**, expected missing cache registration/global identity checks, reference-text consistency, whitelist and old-content withdrawal.
2. Server cwd: `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe test --reporter expanded test/mother_pattern_validation_test.dart test/content_api_test.dart`
   - task-4-server-red.log: **6 passed / 51 failed / exit 1**, expected unregistered new pack and missing ordinary namespace/metadata checks. Invalid-pack tests assert an actual validation reason rather than accepting unknown-pack rejection.
3. Server cwd: `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe test --reporter expanded test/admin_content_editor_test.dart`
   - task-4-admin-red.log: **0 passed / 1 failed / exit 1**, actual served JS had no raw editor. First attempt exceeded Windows argv length; moving the test JS into a temporary file produced this valid behavioral failure.
4. `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe D:/fv_sdk/flutter/bin/cache/flutter_tools.snapshot test --no-pub --concurrency=2 --reporter=expanded test/mother_pattern_content_test.dart`
   - task-4-scenes-red.log: **10 passed / 1 failed / exit 1**, mp_u1l1_e9 repeated a prior scene.
5. Server cwd: `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe test --reporter expanded test/content_audio_audit_test.dart`
   - task-4-audit-red.log: **0 passed / 1 failed / exit 1**, actual audit generated zero new-course rows instead of 483 in a controlled filesystem fixture.
6. Registration test was strengthened to exercise real HTTP manifest/cache synchronization. Temporarily removed only the new registration line, ran `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe D:/fv_sdk/flutter/bin/cache/flutter_tools.snapshot test --no-pub --concurrency=2 --reporter=expanded test/mother_pattern_overlay_test.dart --plain-name 'independent registration loads the published pack'`, then restored registration.
   - task-4-cache-registration-red.log: **0 passed / 1 failed / exit 1**, loader received bundled title instead of Published. Final full targeted run verifies green.

## Final green verification

1. `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe D:/fv_sdk/flutter/bin/cache/flutter_tools.snapshot test --no-pub --concurrency=2 --reporter=expanded test/mother_pattern_overlay_test.dart test/backup_service_test.dart test/pattern_content_test.dart test/pattern_training_model_test.dart test/course_expansion_test.dart test/mother_pattern_content_test.dart test/course_loader_test.dart test/content_overlay_test.dart test/multilingual_course_test.dart`
   - task-4-client-final-green.log: **120 passed / zero failures / exit 0**. Includes 44 invalid independent-pack mutations, ordinary reserved-ID/metadata/identity fallback, actual cached legacy metadata, original content/model/audio, backup and multilingual regressions.
2. Server cwd: `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe test --reporter expanded`
   - task-4-server-final-green.log: **115 passed / 2 skipped / zero failures / exit 0**. Existing PostgreSQL regressions require TEST_DATABASE_URL and remain skipped. New schema, publication lifecycle preserving last valid publication, admin editor and 483-clip audit all run.
3. `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe analyze lib/data/sources/course_loader.dart lib/data/sources/content_documents.dart lib/core/services/backup_service.dart tool/audit_learning_audio.dart tool/validate_course_content.dart tool/generate_pattern_pilot.dart tool/generate_mother_pattern_course.dart test/mother_pattern_overlay_test.dart test/mother_pattern_validation_fixture.dart test/pattern_content_test.dart test/pattern_training_model_test.dart test/backup_service_test.dart test/course_expansion_test.dart test/mother_pattern_content_test.dart`
   - task-4-client-analyze.log: **No issues found / exit 0**.
4. Server cwd: `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe analyze`
   - task-4-server-analyze.log: **No issues found / exit 0**, includes package/server/owned tests.
5. `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe tool/validate_course_content.dart`
   - task-4-content-validation.log: **zero 232 / beginner 272 / intermediate 64 / motherPattern 16 lessons validated / exit 0**.
6. `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe tool/audit_learning_audio.dart --output .superpowers/sdd/2026-11-13-independent-mother-pattern/task-4-audio-audit.json`
   - task-4-audio-audit.log: **2613 files checked / 0 missing or invalid / exit 0**. This verifies existence and MP3 headers, not manual listening or device playback; root owns deeper audio checks.
7. `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe tool/generate_mother_pattern_course.dart --check`
   - task-4-generator-check.log: **authored pack matches; ordinary courses untouched / exit 0**.
8. Client: `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe D:/fv_sdk/flutter/bin/cache/flutter_tools.snapshot pub get --offline`; server cwd: `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe pub get --offline`
   - task-4-client-pub-get.log and task-4-server-pub-get.log: **exit 0**, each adds only mother_pattern_schema.
9. Copied only server bin/lib/schema/pubspec.yaml/pubspec.lock to `.superpowers/sdd/2026-11-13-independent-mother-pattern/task-4-server-context`, without client or parent repository files. In that isolated directory ran `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe pub get --offline` then `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe compile exe bin/server.dart -o server.exe`.
   - task-4-server-isolated-compile.log: **dependency resolution and AOT compilation exit 0**. Docker is unavailable locally, so no Docker build is claimed. Dockerfile now COPYs schema before its first pub get; server build context is self-contained. Root directed keeping the ignored validation context for subsequent managed-worktree archive after automatic cleanup approval rejected recursive deletion.
10. All owned Dart files formatted; `git diff --check` **exit 0**. Git prints expected LF-to-CRLF checkout notices but no whitespace errors.

## Integration notes

Initial cross-lib client relative import was proved invalid by Flutter package-URI resolution (it attempted lib/server/lib); root explicitly approved the small pure package solution plus both pubspec/locks and Docker COPY prerequisite. Its only ongoing cost is a local schema package directory within server; no external package or runtime dependency was added.

Main-lesson 70% passage/rewards, generic celebration dialogues, no-review rewards, hidden independent answers, telemetry storage and legacy UI withdrawal remain in already-reviewed Task1/2/3 code. Task4 did not alter UI/TtsService/model/store/new audio/release version. No physical-device or human next-day recall claim is made. Root will perform the independent Task4 review, full client validation, release build and sharing.

## Root Flutter analysis follow-up

Root's strict whole-repository Flutter analysis reported two new schema missing-block infos in addition to seven unchanged baseline infos. Both new multiline if statements now have blocks and are formatted. Ran `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe D:/fv_sdk/flutter/bin/cache/flutter_tools.snapshot analyze --no-pub --no-fatal-infos` after the correction: **exit 0**, exactly seven baseline info diagnostics, zero errors/warnings (task-4-root-flutter-analyze.log). The remaining infos are old RadioListTile groupValue/onChanged deprecations (2), server/bin print (2), PostgreSQL test missing block (1), language practice test interpolation (1), and old skill generator string composition (1); none is a Task4 behavior change and root directed leaving them unchanged.

Post-block fresh regression: `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe D:/fv_sdk/flutter/bin/cache/flutter_tools.snapshot test --no-pub --concurrency=2 --reporter=expanded test/mother_pattern_overlay_test.dart` passes all 51 loader/cache mutation tests (task-4-post-format-client-green.log); full server final log is refreshed after the correction and remains 115 passed, 2 database skips, exit 0.

## Task4 review fix round 1 (base cb30f15)

Read the complete task-4-review.md. Both Important findings are addressed without restoring production pilot metadata or changing UI/TTS/controllers/stores.

1. `pattern_training_page_test.dart` now explicitly loads the legacy `d691041` beginner JSON using git show, asserts its legacy metadata is present and independent metadata absent, and exercises the retained standalone legacy page/parser. The existing meaningful session, hidden-input-answer, hinted-review/small-screen and account-switch assertions remain. Test names identify legacy behavior. Production assets remain stripped.
2. Moved the exact current English comparison sequence and punctuation regex into public pure `normalizeEnglishAnswer` in `server/schema/lib/english_answer.dart`, exported by the package entry point. Both the independent schema and `Exercise.normalizeAnswer` delegate to that single implementation. No contraction expansion, Unicode/punctuation/whitespace changes, or Chinese/Sanskrit normalization changes were introduced. The existing Exercise static API remains compatible.

Added literal semantic characterization tests for all four folded apostrophe forms, word-internal o'clock, case, ASCII/Unicode punctuation, repeated whitespace/NBSP, blank normalized answers, actual schema reference validation, and runtime acceptance. Additional regressions preserve Chinese/Sanskrit NFC/case/punctuation handling, dictation's whitespace/zero-width-space removal and repeat-mode exclusion of scenario alternatives. Each public helper/runtime output is checked against a hand-authored literal, while the real schema validates the corresponding canonical/reference pair.

### Exact verification

All cwd/PUB_CACHE settings match the earlier report. Root's whole-client log supplied 491 passed / 1 skipped / 2 failed before the fix. This round does not claim a fresh whole-client or whole-server pass; root owns their reruns. Prior database skips and Docker-unavailable distinction remain in force.

- Reproduced legacy red with `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe D:/fv_sdk/flutter/bin/cache/flutter_tools.snapshot test --no-pub --concurrency=2 --reporter=expanded test/pattern_training_page_test.dart`: **1 passed / 2 failed / exit 1**, same null assertions (task-4-fix1-legacy-red.log).
- Before normalization extraction, ran `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe D:/fv_sdk/flutter/bin/cache/flutter_tools.snapshot test --no-pub --concurrency=2 --reporter=expanded test/answer_normalization_test.dart`: **11 passed / exit 0** (task-4-fix1-normalization-before.log). This is a behavior-preserving duplication refactor; no current scoring mismatch is claimed. The pre-extraction passing characterization establishes the semantics to preserve.
- An initial attempt mistakenly ran two Flutter commands concurrently, racing on shared NativeAssetsManifest copying. That tool crash was not a test/product failure; commands were rerun serially and the final before/after logs are valid. Root confirmed no competing Flutter process. A characterization sample initially used Japanese-script punctuation (`・`) rejected by the existing English-content guard; corrected it to the allowed middle dot (`·`) without changing production language validation.
- After extraction/fixture correction, ran `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe D:/fv_sdk/flutter/bin/cache/flutter_tools.snapshot test --no-pub --concurrency=2 --reporter=expanded test/pattern_training_page_test.dart test/answer_normalization_test.dart test/pattern_training_model_test.dart test/mother_pattern_model_test.dart test/mother_pattern_content_test.dart test/pattern_content_test.dart test/mother_pattern_overlay_test.dart test/learning_improvement_test.dart test/multilingual_course_test.dart`: **148 passed / zero failures / exit 0** (task-4-fix1-client-green.log). Includes all three legacy widgets, strict contractions/object/quantity matching, model/content/overlay regressions and non-English grading behavior.
- Server cwd: `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe test --reporter expanded test/mother_pattern_validation_test.dart test/pattern_training_validation_test.dart test/content_api_test.dart`: **78 passed / zero failures / exit 0** (task-4-fix1-server-green.log). These are targeted validator/publication checks; PostgreSQL and Docker were not rerun.
- `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe analyze lib/data/models/course.dart test/answer_normalization_test.dart test/pattern_training_page_test.dart server/schema/lib/english_answer.dart server/schema/lib/mother_pattern_schema.dart`: **No issues found / exit 0** (task-4-fix1-analyze.log).
- `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe D:/fv_sdk/flutter/bin/cache/flutter_tools.snapshot analyze --no-pub lib/data/models/course.dart test/answer_normalization_test.dart test/pattern_training_page_test.dart server/schema/lib/english_answer.dart server/schema/lib/mother_pattern_schema.dart`: **No issues found / exit 0** (task-4-fix1-flutter-analyze.log), including root Flutter lint context for the pure package.
- `D:/fv_sdk/flutter/bin/cache/dart-sdk/bin/dart.exe format lib/data/models/course.dart server/schema/lib/english_answer.dart server/schema/lib/mother_pattern_schema.dart test/answer_normalization_test.dart test/pattern_training_page_test.dart`; `git diff --check`: **exit 0**. Formatting prints the known server-package flutter_lints include lookup notice; actual Dart and Flutter owned analysis are clean.
