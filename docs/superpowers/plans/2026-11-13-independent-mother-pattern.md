# Independent Mother Pattern Course Implementation Plan

**Goal:** Deliver the user-approved independent 16-lesson offline speaking course, withdraw the old six-lesson integration, verify and package a version-named APK.
**Architecture:** Existing Course/Unit/Lesson/Exercise structure; optional patternLesson instructional metadata; dedicated course controller/page and account-scoped review store; existing path, rewards and result persistence.
**Spec:** docs/superpowers/specs/2026-11-13-independent-mother-pattern-design.md
**Global constraints:** 4 units/16 lessons; 12 pattern lessons and 4 dialogue lessons; 10 exercises per lesson; motherPattern course ID; mp_ global prefixes; old courses unchanged except removal of added pilot metadata; strict scenario answers; local-only new records; no answers before independent submission; 70% passage; existing main-course reward behavior; review no rewards; 0.8.52+69 target.

### Task 1: Content and model contract
- Write tests first for independent content availability, stage counts, supported contractions and rejected wrong object/quantity/pattern, legacy parsing, and invalid phase references/tokens.
- Extend Exercise with SpeakingMode {repeat, scenario}, default repeat. Scenario accepts configured alternatives strictly; normal exercises preserve behavior. Extend Lesson with PatternLesson? patternLesson and metadata validation.
- Add CourseTrack.motherPattern and assets/courses/course_mother_pattern.json. Implement a non-destructive generator restricted to this new pack; three examples and four rotating scenario review tasks per pattern; dialogue/lexicon/limitations/phase mapping. Include exact type constructors/fromJson and public API in report for Task 2/3.
- Legacy patternTraining model/parsing retained for compatibility. Content audio generation is Task 5; publish a list of all new audio IDs/texts.
- Own lib/data/models/course.dart, course_track.dart, new pattern_lesson.dart, new generator/content and task-specific tests. Do not edit ordinary UI, LearningStore, server or release files.
- Use direct SDK Dart + flutter_tools.snapshot, PUB_CACHE D:/fv_sdk/pub-cache; test concurrency 2. Report tests with red/green evidence and commit only owned paths.

### Task 2: Session controller and review persistence
- Implement MotherPatternController/state with immutable queue, first attempt/hint/modality tracking, correction without resetting first result, 10-item lesson vs 2-item review, independent IDs from metadata; expose API report to Task 3.
- Implement MotherPatternStore in learning_records Hive storage, separate account suffix motherPatternReviews; per-account serialized saves; key course/pattern/version; durable session dedup and stale snapshot protection. Only due formal reviews advance 3/7/14; success first learning tomorrow otherwise today; dialogue only telemetry; future practice no advancement; cursor only after full valid due review.
- Reuse LearningStore log for answer-free telemetry, include new store records in LearningStore export/clear, retaining old patternReviews unchanged.
- Test correctness, retries, hints, typedFallback distinctions, storage failures/retries, due dates, not-due/stale/double sessions, rotation, restart/account/content-version separation, export/clear. Own new controller/store and LearningStore plus tests; not course models/content/UI/server.
- Record actual interfaces/constructors used by Task 3. Commit owned paths only.

### Task 3: Standalone teaching and spoken interaction
- Dedicated page shows dialogue, vocabulary, Chinese rules, example playback before 10-stage practice; prompts/phase progress and hidden answers until submission. Add scenario speaking UI with injected recorder/recognizer seam, built-in offline ASR, transcript strict matching and explicit typed fallback. Follow existing record/play services and release microphones/PCM on navigation or account switch.
- Existing /lesson route dispatch new page only for motherPattern; ordinary LessonPage/result/review remove pilot hooks even for cached legacy metadata. New result uses existing 70%/reward save then idempotent session save and handles failure; no speculative complete state. Review screen in motherPattern shows due max6 and learned patterns, current snapshot; repeat practice no review advancement/rewards.
- Add bilingual UI strings, adaptive sizing. Test teaching/stages, hidden answer/play prevention, contractions/wrong object, mock PCM recognition/empty/error/denied/fallback, account interruption, save failure/retry, review navigation and 320x560/1.8 fonts.
- Own feature UI/router/strings and UI tests; consult Task 1/2 reports for API. Commit owned paths only.

### Task 4: Integration, rollback and server validation
- Register new pack client/server; reject malformed new metadata/duplicates/tokens and wrong course identity for overlays; admin JSON editor preserve new fields. Remove six injected patternTraining fields only, prove original exercises/IDs byte-equivalent JSON data. Retire old injection generator and adjust tests that asserted pilot presence to compatibility/withdrawal checks.
- Extend backup reward ID whitelist with mp_; preserve backup/sync wire formats. Update audit/validation utilities to inspect new extra content/audio. Add new dialogue audio to appropriate assets without modifying old entries.
- Test server new pack publication, content schema, legacy acceptance, malicious/malformed references, backup round trip, old overlaid courses not showing pilot, no reward regressions. Commit owned changes.

### Task 5: Audio, verification and release
- Generate all dialogue/example/listening/answer/review MP3s from exact text with local Zira/LAME pipeline; content fingerprints and real decoding check. All new audio assets bundled offline; no speech answers autoplay for scenario tasks.
- Full client tests (concurrency2) and analyze; full server tests/analyze, content validator and audio checks. Review feature diff; resolve important findings with targeted regression tests.
- Bump pubspec/constants to 0.8.52+69 unless main already higher; build Android ARM64 release with known SDK/JDK/Gradle low-memory toolchain. Read manifest, verify v2 signature ZIP CRC/hash, ensure all new content/audio present.
- Copy version APK into existing source build/apk-share, maintain existing foreground server, HEAD/full GET hashes, update QR and documentation with version address. Do not terminate old share service. Do not claim actual Android listening/next-day human tests passed without physical evidence.
- Integrate feature commits into user workspace preserving unrelated Gradle/untracked edits; archive managed checkout only after preserving required ignored outputs. Commit task results and delivery docs.
