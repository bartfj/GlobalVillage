import 'dart:convert';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';

import 'content_hash.dart';

/// 一份 JSON 内容包的草稿与已发布文本。
class StoredDocument {
  const StoredDocument({
    required this.packId,
    required this.draftText,
    required this.publishedText,
    required this.revision,
    required this.sha256,
    required this.publishedAt,
    required this.updatedAt,
    bool? hasDraft,
    bool? isPublished,
  }) : hasDraft = hasDraft ?? draftText != null,
       isPublished = isPublished ?? publishedText != null;

  final String packId;
  final String? draftText;
  final String? publishedText;
  final int revision;
  final String? sha256;
  final DateTime? publishedAt;
  final DateTime updatedAt;
  final bool hasDraft;
  final bool isPublished;
}

/// 音频覆盖的元数据。字节按需另取。
class StoredAudio {
  const StoredAudio({
    required this.path,
    required this.hasDraft,
    required this.isPublished,
    required this.revision,
    required this.sha256,
    required this.publishedBytes,
    required this.publishedAt,
    required this.updatedAt,
  });

  final String path;
  final bool hasDraft;
  final bool isPublished;
  final int revision;
  final String? sha256;
  final int publishedBytes;
  final DateTime? publishedAt;
  final DateTime updatedAt;
}

class ContentManifestEntry {
  const ContentManifestEntry({
    required this.id,
    required this.revision,
    required this.sha256,
    required this.bytes,
  });

  final String id;
  final int revision;
  final String sha256;
  final int bytes;

  Map<String, Object?> toJson() => {
    'id': id,
    'revision': revision,
    'sha256': sha256,
    'bytes': bytes,
  };
}

class ContentFileManifestEntry {
  const ContentFileManifestEntry({
    required this.path,
    required this.revision,
    required this.sha256,
    required this.bytes,
  });

  final String path;
  final int revision;
  final String sha256;
  final int bytes;

  Map<String, Object?> toJson() => {
    'path': path,
    'revision': revision,
    'sha256': sha256,
    'bytes': bytes,
  };
}

abstract class ContentRepo {
  Future<List<StoredDocument>> listDocuments();

  Future<StoredDocument?> getDocument(String packId);

  Future<StoredDocument> saveDraft(String packId, String text);

  /// 没有草稿时返回 null。
  Future<StoredDocument?> publishDocument(String packId);

  /// 没有记录时返回 null。撤回后已发布正文清空，修订号保留。
  Future<StoredDocument?> unpublishDocument(String packId);

  Future<List<StoredAudio>> listAudio();

  Future<StoredAudio?> getAudio(String path);

  Future<List<int>?> publishedAudio(String path);

  Future<StoredAudio> saveAudioDraft(String path, List<int> bytes);

  Future<StoredAudio?> publishAudio(String path);

  Future<StoredAudio?> unpublishAudio(String path);

  Future<Map<String, Object?>> manifest();
}

class _MemoryDocument {
  String? draftText;
  String? publishedText;
  int revision = 0;
  String? sha256;
  DateTime? publishedAt;
  DateTime updatedAt = DateTime.now().toUtc();

  StoredDocument toStored(String packId) => StoredDocument(
    packId: packId,
    draftText: draftText,
    publishedText: publishedText,
    revision: revision,
    sha256: sha256,
    publishedAt: publishedAt,
    updatedAt: updatedAt,
  );
}

class _MemoryAudio {
  List<int>? draftBytes;
  List<int>? publishedBytes;
  int revision = 0;
  String? sha256;
  DateTime? publishedAt;
  DateTime updatedAt = DateTime.now().toUtc();

  StoredAudio toStored(String path) => StoredAudio(
    path: path,
    hasDraft: draftBytes != null,
    isPublished: publishedBytes != null,
    revision: revision,
    sha256: sha256,
    publishedBytes: publishedBytes?.length ?? 0,
    publishedAt: publishedAt,
    updatedAt: updatedAt,
  );
}

class InMemoryContentRepo implements ContentRepo {
  final _documents = <String, _MemoryDocument>{};
  final _audio = <String, _MemoryAudio>{};

  @override
  Future<List<StoredDocument>> listDocuments() async => [
    for (final entry in _documents.entries) entry.value.toStored(entry.key),
  ];

  @override
  Future<StoredDocument?> getDocument(String packId) async =>
      _documents[packId]?.toStored(packId);

  @override
  Future<StoredDocument> saveDraft(String packId, String text) async {
    final doc = _documents.putIfAbsent(packId, _MemoryDocument.new);
    doc.draftText = text;
    doc.updatedAt = DateTime.now().toUtc();
    return doc.toStored(packId);
  }

  @override
  Future<StoredDocument?> publishDocument(String packId) async {
    final doc = _documents[packId];
    final draft = doc?.draftText;
    if (doc == null || draft == null) return null;
    doc.publishedText = draft;
    doc.revision += 1;
    doc.sha256 = await contentSha256(utf8.encode(draft));
    doc.publishedAt = DateTime.now().toUtc();
    doc.updatedAt = doc.publishedAt!;
    return doc.toStored(packId);
  }

  @override
  Future<StoredDocument?> unpublishDocument(String packId) async {
    final doc = _documents[packId];
    if (doc == null) return null;
    doc.publishedText = null;
    doc.sha256 = null;
    doc.publishedAt = null;
    doc.updatedAt = DateTime.now().toUtc();
    return doc.toStored(packId);
  }

  @override
  Future<List<StoredAudio>> listAudio() async => [
    for (final entry in _audio.entries) entry.value.toStored(entry.key),
  ];

  @override
  Future<StoredAudio?> getAudio(String path) async =>
      _audio[path]?.toStored(path);

  @override
  Future<List<int>?> publishedAudio(String path) async {
    final bytes = _audio[path]?.publishedBytes;
    if (bytes == null) return null;
    return List<int>.from(bytes);
  }

  @override
  Future<StoredAudio> saveAudioDraft(String path, List<int> bytes) async {
    final file = _audio.putIfAbsent(path, _MemoryAudio.new);
    file.draftBytes = List<int>.from(bytes);
    file.updatedAt = DateTime.now().toUtc();
    return file.toStored(path);
  }

  @override
  Future<StoredAudio?> publishAudio(String path) async {
    final file = _audio[path];
    final draft = file?.draftBytes;
    if (file == null || draft == null) return null;
    file.publishedBytes = List<int>.from(draft);
    file.revision += 1;
    file.sha256 = await contentSha256(draft);
    file.publishedAt = DateTime.now().toUtc();
    file.updatedAt = file.publishedAt!;
    return file.toStored(path);
  }

  @override
  Future<StoredAudio?> unpublishAudio(String path) async {
    final file = _audio[path];
    if (file == null) return null;
    file.publishedBytes = null;
    file.sha256 = null;
    file.publishedAt = null;
    file.updatedAt = DateTime.now().toUtc();
    return file.toStored(path);
  }

  @override
  Future<Map<String, Object?>> manifest() async {
    final documents = <ContentManifestEntry>[];
    for (final entry in _documents.entries) {
      final text = entry.value.publishedText;
      final sha = entry.value.sha256;
      if (text == null || sha == null) continue;
      documents.add(
        ContentManifestEntry(
          id: entry.key,
          revision: entry.value.revision,
          sha256: sha,
          bytes: utf8.encode(text).length,
        ),
      );
    }
    documents.sort((a, b) => a.id.compareTo(b.id));

    final files = <ContentFileManifestEntry>[];
    for (final entry in _audio.entries) {
      final bytes = entry.value.publishedBytes;
      final sha = entry.value.sha256;
      if (bytes == null || sha == null) continue;
      files.add(
        ContentFileManifestEntry(
          path: entry.key,
          revision: entry.value.revision,
          sha256: sha,
          bytes: bytes.length,
        ),
      );
    }
    files.sort((a, b) => a.path.compareTo(b.path));

    return {
      'documents': [for (final item in documents) item.toJson()],
      'files': [for (final item in files) item.toJson()],
    };
  }
}

class PostgresContentRepo implements ContentRepo {
  PostgresContentRepo._(this._conn);

  final Connection _conn;

  static Future<PostgresContentRepo> connect(String databaseUrl) async {
    final uri = Uri.parse(databaseUrl);
    final userInfo = uri.userInfo.split(':');
    final sslRequired = uri.queryParameters['sslmode'] == 'require';
    final conn = await Connection.open(
      Endpoint(
        host: uri.host.isEmpty ? 'localhost' : uri.host,
        port: uri.port == 0 ? 5432 : uri.port,
        database: uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first
            : 'postgres',
        username: userInfo.first.isEmpty ? null : userInfo.first,
        password: userInfo.length > 1 ? userInfo.sublist(1).join(':') : null,
      ),
      settings: ConnectionSettings(
        sslMode: sslRequired ? SslMode.require : SslMode.disable,
      ),
    );
    final repo = PostgresContentRepo._(conn);
    await repo._migrate();
    return repo;
  }

  Future<void> _migrate() async {
    await _conn.execute('''
CREATE TABLE IF NOT EXISTS content_documents (
  pack_id text PRIMARY KEY,
  draft_text text,
  published_text text,
  revision int NOT NULL DEFAULT 0,
  sha256 text,
  published_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
)
''');
    await _conn.execute('''
CREATE TABLE IF NOT EXISTS content_files (
  path text PRIMARY KEY,
  draft_bytes bytea,
  published_bytes bytea,
  revision int NOT NULL DEFAULT 0,
  sha256 text,
  published_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
)
''');
  }

  @override
  Future<List<StoredDocument>> listDocuments() async {
    final result = await _conn.execute('''
SELECT pack_id, revision, sha256, published_at, updated_at,
       draft_text IS NOT NULL AS has_draft,
       published_text IS NOT NULL AS is_published
FROM content_documents
ORDER BY pack_id
''');
    return [for (final row in result) _documentSummary(row.toColumnMap())];
  }

  @override
  Future<StoredDocument?> getDocument(String packId) async {
    final result = await _conn.execute(
      Sql.named('''
SELECT pack_id, draft_text, published_text, revision, sha256,
       published_at, updated_at
FROM content_documents
WHERE pack_id = @id
'''),
      parameters: {'id': packId},
    );
    if (result.isEmpty) return null;
    return _documentFull(result.first.toColumnMap());
  }

  @override
  Future<StoredDocument> saveDraft(String packId, String text) async {
    final result = await _conn.execute(
      Sql.named('''
INSERT INTO content_documents (pack_id, draft_text, updated_at)
VALUES (@id, @text, now())
ON CONFLICT (pack_id) DO UPDATE
SET draft_text = EXCLUDED.draft_text, updated_at = now()
RETURNING pack_id, draft_text, published_text, revision, sha256,
          published_at, updated_at
'''),
      parameters: {'id': packId, 'text': text},
    );
    return _documentFull(result.first.toColumnMap());
  }

  @override
  Future<StoredDocument?> publishDocument(String packId) async {
    final current = await getDocument(packId);
    final draft = current?.draftText;
    if (current == null || draft == null) return null;
    final sha = await contentSha256(utf8.encode(draft));
    final result = await _conn.execute(
      Sql.named('''
UPDATE content_documents
SET published_text = @text,
    revision = revision + 1,
    sha256 = @sha,
    published_at = now(),
    updated_at = now()
WHERE pack_id = @id AND draft_text IS NOT NULL
RETURNING pack_id, draft_text, published_text, revision, sha256,
          published_at, updated_at
'''),
      parameters: {'id': packId, 'text': draft, 'sha': sha},
    );
    if (result.isEmpty) return null;
    return _documentFull(result.first.toColumnMap());
  }

  @override
  Future<StoredDocument?> unpublishDocument(String packId) async {
    final result = await _conn.execute(
      Sql.named('''
UPDATE content_documents
SET published_text = NULL, sha256 = NULL, published_at = NULL, updated_at = now()
WHERE pack_id = @id
RETURNING pack_id, draft_text, published_text, revision, sha256,
          published_at, updated_at
'''),
      parameters: {'id': packId},
    );
    if (result.isEmpty) return null;
    return _documentFull(result.first.toColumnMap());
  }

  @override
  Future<List<StoredAudio>> listAudio() async {
    final result = await _conn.execute('''
SELECT path, revision, sha256, published_at, updated_at,
       draft_bytes IS NOT NULL AS has_draft,
       published_bytes IS NOT NULL AS is_published,
       COALESCE(octet_length(published_bytes), 0) AS published_len
FROM content_files
ORDER BY path
''');
    return [for (final row in result) _audioSummary(row.toColumnMap())];
  }

  @override
  Future<StoredAudio?> getAudio(String path) async {
    final result = await _conn.execute(
      Sql.named('''
SELECT path, revision, sha256, published_at, updated_at,
       draft_bytes IS NOT NULL AS has_draft,
       published_bytes IS NOT NULL AS is_published,
       COALESCE(octet_length(published_bytes), 0) AS published_len
FROM content_files
WHERE path = @path
'''),
      parameters: {'path': path},
    );
    if (result.isEmpty) return null;
    return _audioSummary(result.first.toColumnMap());
  }

  @override
  Future<List<int>?> publishedAudio(String path) async {
    final result = await _conn.execute(
      Sql.named('''
SELECT published_bytes FROM content_files WHERE path = @path
'''),
      parameters: {'path': path},
    );
    if (result.isEmpty) return null;
    final bytes = result.first.toColumnMap()['published_bytes'];
    if (bytes is! List<int>) return null;
    return List<int>.from(bytes);
  }

  @override
  Future<StoredAudio> saveAudioDraft(String path, List<int> bytes) async {
    final result = await _conn.execute(
      Sql.named('''
INSERT INTO content_files (path, draft_bytes, updated_at)
VALUES (@path, @bytes, now())
ON CONFLICT (path) DO UPDATE
SET draft_bytes = EXCLUDED.draft_bytes, updated_at = now()
RETURNING path, revision, sha256, published_at, updated_at,
          draft_bytes IS NOT NULL AS has_draft,
          published_bytes IS NOT NULL AS is_published,
          COALESCE(octet_length(published_bytes), 0) AS published_len
'''),
      parameters: {
        'path': path,
        'bytes': TypedValue(Type.byteArray, Uint8List.fromList(bytes)),
      },
    );
    return _audioSummary(result.first.toColumnMap());
  }

  @override
  Future<StoredAudio?> publishAudio(String path) async {
    final current = await _conn.execute(
      Sql.named('''
SELECT draft_bytes FROM content_files WHERE path = @path
'''),
      parameters: {'path': path},
    );
    if (current.isEmpty) return null;
    final draft = current.first.toColumnMap()['draft_bytes'];
    if (draft is! List<int>) return null;
    final sha = await contentSha256(draft);
    final result = await _conn.execute(
      Sql.named('''
UPDATE content_files
SET published_bytes = @bytes,
    revision = revision + 1,
    sha256 = @sha,
    published_at = now(),
    updated_at = now()
WHERE path = @path AND draft_bytes IS NOT NULL
RETURNING path, revision, sha256, published_at, updated_at,
          draft_bytes IS NOT NULL AS has_draft,
          published_bytes IS NOT NULL AS is_published,
          COALESCE(octet_length(published_bytes), 0) AS published_len
'''),
      parameters: {
        'path': path,
        'bytes': TypedValue(Type.byteArray, Uint8List.fromList(draft)),
        'sha': sha,
      },
    );
    if (result.isEmpty) return null;
    return _audioSummary(result.first.toColumnMap());
  }

  @override
  Future<StoredAudio?> unpublishAudio(String path) async {
    final result = await _conn.execute(
      Sql.named('''
UPDATE content_files
SET published_bytes = NULL, sha256 = NULL, published_at = NULL, updated_at = now()
WHERE path = @path
RETURNING path, revision, sha256, published_at, updated_at,
          draft_bytes IS NOT NULL AS has_draft,
          published_bytes IS NOT NULL AS is_published,
          COALESCE(octet_length(published_bytes), 0) AS published_len
'''),
      parameters: {'path': path},
    );
    if (result.isEmpty) return null;
    return _audioSummary(result.first.toColumnMap());
  }

  @override
  Future<Map<String, Object?>> manifest() async {
    final documents = await _conn.execute('''
SELECT pack_id, revision, sha256, octet_length(published_text) AS bytes
FROM content_documents
WHERE published_text IS NOT NULL AND sha256 IS NOT NULL
ORDER BY pack_id
''');
    final files = await _conn.execute('''
SELECT path, revision, sha256, octet_length(published_bytes) AS bytes
FROM content_files
WHERE published_bytes IS NOT NULL AND sha256 IS NOT NULL
ORDER BY path
''');
    return {
      'documents': [
        for (final row in documents)
          {
            'id': row.toColumnMap()['pack_id'],
            'revision': row.toColumnMap()['revision'],
            'sha256': row.toColumnMap()['sha256'],
            'bytes': row.toColumnMap()['bytes'],
          },
      ],
      'files': [
        for (final row in files)
          {
            'path': row.toColumnMap()['path'],
            'revision': row.toColumnMap()['revision'],
            'sha256': row.toColumnMap()['sha256'],
            'bytes': row.toColumnMap()['bytes'],
          },
      ],
    };
  }

  StoredDocument _documentSummary(Map<String, dynamic> row) => StoredDocument(
    packId: row['pack_id'] as String,
    draftText: null,
    publishedText: null,
    hasDraft: row['has_draft'] == true,
    isPublished: row['is_published'] == true,
    revision: row['revision'] as int,
    sha256: row['sha256'] as String?,
    publishedAt: row['published_at'] as DateTime?,
    updatedAt: row['updated_at'] as DateTime,
  );

  StoredDocument _documentFull(Map<String, dynamic> row) => StoredDocument(
    packId: row['pack_id'] as String,
    draftText: row['draft_text'] as String?,
    publishedText: row['published_text'] as String?,
    revision: row['revision'] as int,
    sha256: row['sha256'] as String?,
    publishedAt: row['published_at'] as DateTime?,
    updatedAt: row['updated_at'] as DateTime,
  );

  StoredAudio _audioSummary(Map<String, dynamic> row) => StoredAudio(
    path: row['path'] as String,
    hasDraft: row['has_draft'] == true,
    isPublished: row['is_published'] == true,
    revision: row['revision'] as int,
    sha256: row['sha256'] as String?,
    publishedBytes: (row['published_len'] as int?) ?? 0,
    publishedAt: row['published_at'] as DateTime?,
    updatedAt: row['updated_at'] as DateTime,
  );
}
