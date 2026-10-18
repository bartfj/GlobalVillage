import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'content_catalog.dart';
import 'content_repo.dart';
import 'content_validate.dart';

void mountPublicContent(Router router, ContentRepo content) {
  router.get('/v1/content/manifest', (Request request) async {
    return _json(200, await content.manifest());
  });

  router.get('/v1/content/packs/<kind>/<name>', (
    Request request,
    String kind,
    String name,
  ) async {
    final spec = contentPackById('$kind/$name');
    if (spec == null) return _error(404, 'not_found', '内容不存在');
    final doc = await content.getDocument(spec.id);
    final text = doc?.publishedText;
    if (doc == null || !doc.isPublished || text == null) {
      return _error(404, 'not_found', '内容不存在');
    }
    return Response.ok(
      text,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        if (doc.sha256 != null) 'etag': doc.sha256!,
      },
    );
  });

  router.get('/v1/content/files/<scope>/<bucket>/<file>', (
    Request request,
    String scope,
    String bucket,
    String file,
  ) async {
    final path = '$scope/$bucket/$file';
    if (!contentAudioPath.hasMatch(path)) {
      return _error(404, 'not_found', '音频不存在');
    }
    final bytes = await content.publishedAudio(path);
    if (bytes == null) return _error(404, 'not_found', '音频不存在');
    return Response.ok(bytes, headers: {'content-type': 'audio/mpeg'});
  });
}

void mountAdminContent(
  Router router,
  ContentRepo content,
  bool Function(Request request) allowed,
) {
  router.get('/admin/api/content/packs', (Request request) async {
    if (!allowed(request)) return _unauthorized();
    final stored = {
      for (final doc in await content.listDocuments()) doc.packId: doc,
    };
    return _json(200, {
      'packs': [
        for (final spec in contentPackSpecs)
          _packSummary(spec, stored[spec.id]),
      ],
    });
  });

  router.get('/admin/api/content/packs/<kind>/<name>', (
    Request request,
    String kind,
    String name,
  ) async {
    if (!allowed(request)) return _unauthorized();
    final spec = contentPackById('$kind/$name');
    if (spec == null) return _error(404, 'not_found', '内容包不存在');
    final doc = await content.getDocument(spec.id);
    final source = request.url.queryParameters['source'];
    return _json(200, _packDetail(spec, doc, source: source));
  });

  router.put('/admin/api/content/packs/<kind>/<name>', (
    Request request,
    String kind,
    String name,
  ) async {
    if (!allowed(request)) return _unauthorized();
    final spec = contentPackById('$kind/$name');
    if (spec == null) return _error(404, 'not_found', '内容包不存在');
    final text = await request.readAsString();
    if (utf8.encode(text).length > maxContentJsonBytes) {
      return _error(400, 'too_large', '内容过大');
    }
    final body = _object(text);
    if (body == null) return _error(400, 'invalid_body', '请求体必须是 JSON 对象');
    final canonical = jsonEncode(body);
    final saved = await content.saveDraft(spec.id, canonical);
    return _json(200, _packDetail(spec, saved));
  });

  router.post('/admin/api/content/packs/<kind>/<name>/publish', (
    Request request,
    String kind,
    String name,
  ) async {
    if (!allowed(request)) return _unauthorized();
    final spec = contentPackById('$kind/$name');
    if (spec == null) return _error(404, 'not_found', '内容包不存在');
    final current = await content.getDocument(spec.id);
    final draft = current?.draftText;
    if (current == null || !current.hasDraft || draft == null) {
      return _error(400, 'no_draft', '没有可发布的草稿');
    }
    final error = validateContentPack(spec.id, draft);
    if (error != null) return _error(400, 'invalid_content', error);
    final published = await content.publishDocument(spec.id);
    if (published == null) return _error(400, 'no_draft', '没有可发布的草稿');
    return _json(200, _packDetail(spec, published));
  });

  router.post('/admin/api/content/packs/<kind>/<name>/unpublish', (
    Request request,
    String kind,
    String name,
  ) async {
    if (!allowed(request)) return _unauthorized();
    final spec = contentPackById('$kind/$name');
    if (spec == null) return _error(404, 'not_found', '内容包不存在');
    final updated = await content.unpublishDocument(spec.id);
    return _json(200, _packDetail(spec, updated));
  });

  router.get('/admin/api/content/files', (Request request) async {
    if (!allowed(request)) return _unauthorized();
    final files = await content.listAudio();
    return _json(200, {
      'files': [for (final file in files) _audioJson(file)],
    });
  });

  router.put('/admin/api/content/files/<scope>/<bucket>/<file>', (
    Request request,
    String scope,
    String bucket,
    String file,
  ) async {
    if (!allowed(request)) return _unauthorized();
    final path = '$scope/$bucket/$file';
    if (!contentAudioPath.hasMatch(path)) {
      return _error(400, 'invalid_path', '音频路径无效');
    }
    final bytes = await _readBytes(request);
    if (bytes.isEmpty) return _error(400, 'invalid_body', '音频不能为空');
    if (bytes.length > maxContentAudioBytes) {
      return _error(400, 'too_large', '音频过大');
    }
    final saved = await content.saveAudioDraft(path, bytes);
    return _json(200, _audioJson(saved));
  });

  router.post('/admin/api/content/files/<scope>/<bucket>/<file>/publish', (
    Request request,
    String scope,
    String bucket,
    String file,
  ) async {
    if (!allowed(request)) return _unauthorized();
    final path = '$scope/$bucket/$file';
    if (!contentAudioPath.hasMatch(path)) {
      return _error(400, 'invalid_path', '音频路径无效');
    }
    final published = await content.publishAudio(path);
    if (published == null) return _error(400, 'no_draft', '没有可发布的音频草稿');
    return _json(200, _audioJson(published));
  });

  router.post('/admin/api/content/files/<scope>/<bucket>/<file>/unpublish', (
    Request request,
    String scope,
    String bucket,
    String file,
  ) async {
    if (!allowed(request)) return _unauthorized();
    final path = '$scope/$bucket/$file';
    if (!contentAudioPath.hasMatch(path)) {
      return _error(400, 'invalid_path', '音频路径无效');
    }
    final updated = await content.unpublishAudio(path);
    if (updated == null) return _error(404, 'not_found', '音频不存在');
    return _json(200, _audioJson(updated));
  });
}

Map<String, Object?> _packSummary(ContentPackSpec spec, StoredDocument? doc) =>
    {
      'id': spec.id,
      'label': spec.label,
      'kind': spec.kind,
      'revision': doc?.revision ?? 0,
      'hasDraft': doc?.hasDraft ?? false,
      'published': doc?.isPublished ?? false,
      'sha256': doc?.isPublished == true ? doc?.sha256 : null,
      'updatedAt': doc?.updatedAt.toUtc().toIso8601String(),
    };

Map<String, Object?> _packDetail(
  ContentPackSpec spec,
  StoredDocument? doc, {
  String? source,
}) {
  final summary = _packSummary(spec, doc);
  String? text;
  var bodySource = 'none';
  if (source == 'published' && doc?.publishedText != null) {
    text = doc!.publishedText;
    bodySource = 'published';
  } else if (doc?.draftText != null) {
    text = doc!.draftText;
    bodySource = 'draft';
  } else if (doc?.publishedText != null) {
    text = doc!.publishedText;
    bodySource = 'published';
  }
  summary['bodySource'] = bodySource;
  summary['body'] = text == null ? null : jsonDecode(text);
  return summary;
}

Map<String, Object?> _audioJson(StoredAudio file) => {
  'path': file.path,
  'revision': file.revision,
  'hasDraft': file.hasDraft,
  'published': file.isPublished,
  'bytes': file.publishedBytes,
  'sha256': file.isPublished ? file.sha256 : null,
  'updatedAt': file.updatedAt.toUtc().toIso8601String(),
};

Map<String, dynamic>? _object(String text) {
  try {
    final value = jsonDecode(text);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  } catch (_) {
    return null;
  }
}

Future<List<int>> _readBytes(Request request) async {
  final chunks = await request.read().toList();
  final bytes = <int>[];
  for (final chunk in chunks) {
    bytes.addAll(chunk);
  }
  return bytes;
}

Response _json(int status, Map<String, Object?> body) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Response _error(int status, String code, String message) =>
    _json(status, {'code': code, 'message': message});

Response _unauthorized() => _error(401, 'invalid_token', '管理口令无效');
