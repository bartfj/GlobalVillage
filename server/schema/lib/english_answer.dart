/// Existing English grading normalization, shared by runtime acceptance and
/// published-course reference/chunk validation. Explicit answer alternatives
/// are still authored separately; this does not expand contractions or meaning.
String normalizeEnglishAnswer(String text) => text
    .trim()
    .toLowerCase()
    .replaceAll(_curlyApostrophe, "'")
    .replaceAll(_ignoredPunctuation, ' ')
    .replaceAll(_whitespace, ' ')
    .trim();

// Fold apostrophes first so contractions and o'clock retain their word-internal
// apostrophe when the existing punctuation set is replaced with spaces.
final _curlyApostrophe = RegExp("[‘’´`]");
final _ignoredPunctuation = RegExp(
  r'[\[\].,;:!?。，、；：！？．…·・•~～—–‐‑‒―"“”„«»「」『』()（）-]+',
);
final _whitespace = RegExp(r'\s+');
