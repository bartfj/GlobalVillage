import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/services/diagnostic_log.dart';
import '../../core/services/sanskrit_audio_service.dart';
import '../../data/models/sanskrit_sound.dart';
import 'sanskrit_audio_providers.dart';

/// 参考听读，不改变系统课程、专项题库、进度或评分规则。
class SanskritAudioPage extends ConsumerStatefulWidget {
  const SanskritAudioPage({super.key});

  @override
  ConsumerState<SanskritAudioPage> createState() => _SanskritAudioPageState();
}

class _SanskritAudioPageState extends ConsumerState<SanskritAudioPage>
    with WidgetsBindingObserver {
  String _group = 'vowel';
  String _selectedId = 'a';
  String? _playingId;
  Set<String> _cached = {};
  bool _slow = false;
  bool _repeat = false;
  bool _downloading = false;
  int _playSerial = 0;
  int _downloadSerial = 0;
  late final SanskritAudioService _audio;

  String _t(String zh, String en) => ref.read(stringsProvider).isEn ? en : zh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio = ref.read(sanskritAudioServiceProvider);
    unawaited(_refreshCache());
  }

  Future<void> _refreshCache() async {
    try {
      final catalog = await ref.read(sanskritSoundCatalogProvider.future);
      final repo = await ref.read(sanskritAudioRepositoryProvider.future);
      final cached = await repo.cachedIds(catalog.sounds);
      if (mounted) setState(() => _cached = cached);
    } catch (error, stack) {
      recordDiagnosticError('sanskrit-audio-cache', error, stack);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_playSerial;
    ++_downloadSerial;
    unawaited(_audio.stop());
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _stop() {
    ++_playSerial;
    unawaited(_audio.stop());
    if (mounted) setState(() => _playingId = null);
  }

  Future<void> _play(SanskritSound sound) async {
    final serial = ++_playSerial;
    setState(() {
      _selectedId = sound.id;
      _playingId = sound.id;
    });
    final result = await _audio.play(
      sound,
      rate: _slow ? .75 : 1,
      repetitions: _repeat ? 3 : 1,
    );
    if (!mounted || serial != _playSerial) return;
    setState(() => _playingId = null);
    if (result == SanskritPlaybackResult.failed) {
      _message(
        _t(
          '音频播放失败，请检查网络和媒体音量后重试。已下载的录音可离线播放。',
          'Audio unavailable. Check your connection and media volume, then retry. Downloaded recordings work offline.',
        ),
      );
    }
    await _refreshCache();
  }

  Future<void> _downloadAll(SanskritSoundCatalog catalog) async {
    final serial = ++_downloadSerial;
    setState(() => _downloading = true);
    var failed = 0;
    try {
      final repo = await ref.read(sanskritAudioRepositoryProvider.future);
      for (final sound in catalog.sounds) {
        if (!mounted || serial != _downloadSerial) return;
        try {
          await repo.fileFor(sound);
          if (mounted) setState(() => _cached.add(sound.id));
        } catch (error, stack) {
          recordDiagnosticError('sanskrit-audio-download', error, stack);
          failed++;
        }
      }
      if (!mounted || serial != _downloadSerial) return;
      _message(
        failed == 0
            ? _t(
                '录音已下载，可以离线听读。',
                'Recordings downloaded for offline listening.',
              )
            : _t(
                '$failed 个录音未下载成功，可稍后重试；其余已保留。',
                '$failed recordings could not be downloaded. Retry later; other files were kept.',
              ),
      );
    } catch (error, stack) {
      recordDiagnosticError('sanskrit-audio-download', error, stack);
      _message(
        _t('无法准备离线音频，请稍后重试。', 'Cannot prepare offline audio. Please retry.'),
      );
    } finally {
      if (mounted && serial == _downloadSerial) {
        setState(() => _downloading = false);
      }
    }
  }

  void _showSource(SanskritSoundCatalog catalog) {
    final source = catalog.source;
    final url = source['pageUrl'] as String;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('音频来源', 'Audio source'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              Text(
                source['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(url),
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 17),
                label: Text(_t('复制来源链接', 'Copy source link')),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  _message(_t('来源链接已复制。', 'Source link copied.'));
                },
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  '链接与文件校验日期：${source['checkedOn']}。录音内容与字音对应仍待梵文教师审校，供参考听读。',
                  'Links and file checks: ${source['checkedOn']}. Pronunciation and letter mappings await professional review; recordings are listening references.',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _t(
                  '再分发授权尚未确认。安装包只包含来源清单；录音从原站按需下载至当前设备。',
                  'Redistribution permission is unconfirmed. The app bundles a source catalog; recordings are downloaded from the original site to this device.',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _t(
                  '辅音示范带 a。ṃ 和 ḥ 是附加标记，实际读法与后续音及诵读传统有关。慢速播放只帮助听清细节，长短音比较请使用原速。',
                  'Consonants are demonstrated with a. The signs ṃ and ḥ vary with context and recitation tradition. Use normal speed to compare vowel length.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    // Keep auto-disposed audio resources alive until this page leaves the tree.
    ref.watch(sanskritAudioServiceProvider);
    final asyncCatalog = ref.watch(sanskritSoundCatalogProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.sanskritAudioTitle),
        actions: [
          if (asyncCatalog.asData case final data?)
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: _t('音频来源', 'Audio source'),
              onPressed: () => _showSource(data.value),
            ),
        ],
      ),
      body: asyncCatalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_t('发音资料加载失败', 'Could not load audio catalog')),
              TextButton(
                onPressed: () => ref.invalidate(sanskritSoundCatalogProvider),
                child: Text(_t('重试', 'Retry')),
              ),
            ],
          ),
        ),
        data: _content,
      ),
    );
  }

  Widget _content(SanskritSoundCatalog catalog) {
    final selected = catalog.sounds.firstWhere((s) => s.id == _selectedId);
    final groups = [
      ('vowel', _t('元音', 'Vowels')),
      ('velar', _t('软腭音', 'Velars')),
      ('palatal', _t('硬腭音', 'Palatals')),
      ('retroflex', _t('卷舌音', 'Retroflexes')),
      ('dental', _t('齿音', 'Dentals')),
      ('labial', _t('唇音', 'Labials')),
      ('other', _t('其余音', 'Other sounds')),
      ('pairs', _t('对比听读', 'Compare')),
    ];
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('听一遍，再跟读一遍', 'Listen, then repeat'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _t(
                    '48 个基础音与附加标记 · Arsha Vidya UK 参考示范',
                    '48 sounds and signs · Arsha Vidya UK listening references',
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _t(
                        '已离线 ${_cached.length}/${catalog.sounds.length}',
                        'Offline ${_cached.length}/${catalog.sounds.length}',
                      ),
                      style: const TextStyle(
                        color: AppColors.greenDark,
                        fontSize: 12,
                      ),
                    ),
                    TextButton.icon(
                      icon: Icon(
                        _downloading
                            ? Icons.stop_circle_outlined
                            : Icons.download_for_offline_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _downloading
                            ? _t('停止下载', 'Stop download')
                            : _t('下载全部 · 约 300 KB', 'Download all · ~300 KB'),
                      ),
                      onPressed: () {
                        if (_downloading) {
                          ++_downloadSerial;
                          setState(() => _downloading = false);
                        } else {
                          unawaited(_downloadAll(catalog));
                        }
                      },
                    ),
                  ],
                ),
                if (_downloading)
                  LinearProgressIndicator(
                    value: _cached.length / catalog.sounds.length,
                    minHeight: 3,
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                for (final (id, name) in groups)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey('group-$id'),
                      label: Text(name),
                      selected: _group == id,
                      onSelected: (_) => setState(() => _group = id),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _group == 'pairs' ? _pairs(catalog) : _grid(catalog)),
          const Divider(height: 1),
          _playerPanel(selected),
        ],
      ),
    );
  }

  Widget _grid(SanskritSoundCatalog catalog) {
    final sounds = catalog.sounds.where((s) => s.group == _group).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth - 40) / 76).floor().clamp(3, 8);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 98,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: sounds.length,
          itemBuilder: (context, i) => _soundTile(sounds[i]),
        );
      },
    );
  }

  Widget _soundTile(SanskritSound sound) {
    final selected = sound.id == _selectedId;
    final playing = sound.id == _playingId;
    return Semantics(
      label: '${sound.devanagari} ${sound.iast}',
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.greenLight : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.greenDark : AppColors.locked,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('sound-${sound.id}'),
          onTap: () => _play(sound),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                sound.devanagari,
                style: const TextStyle(
                  fontFamily: 'Sanskrit',
                  fontSize: 30,
                  height: 1.4,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    sound.iast,
                    style: const TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 15,
                    ),
                  ),
                  if (playing || _cached.contains(sound.id)) ...[
                    const SizedBox(width: 4),
                    Icon(
                      playing
                          ? Icons.volume_up_rounded
                          : Icons.offline_pin_outlined,
                      size: 12,
                      color: AppColors.greenDark,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pairs(SanskritSoundCatalog catalog) {
    final pairs = [
      ('a', 'aa', _t('长短元音', 'Vowel length')),
      ('i', 'ii', _t('长短元音', 'Vowel length')),
      ('u', 'uu', _t('长短元音', 'Vowel length')),
      ('ka', 'kha', _t('是否送气', 'Aspiration')),
      ('ga', 'gha', _t('是否送气', 'Aspiration')),
      ('ta', 'tta', _t('齿音 / 卷舌音', 'Dental / retroflex')),
      ('na', 'nna', _t('齿音 / 卷舌音', 'Dental / retroflex')),
      ('sha', 'ssa', _t('硬腭 / 卷舌擦音', 'Palatal / retroflex sibilant')),
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      itemCount: pairs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final (left, right, label) = pairs[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            SizedBox(
              height: 98,
              child: Row(
                children: [
                  Expanded(
                    child: _soundTile(
                      catalog.sounds.firstWhere((s) => s.id == left),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(
                      Icons.compare_arrows_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: _soundTile(
                      catalog.sounds.firstWhere((s) => s.id == right),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _playerPanel(SanskritSound sound) {
    final busy = _playingId != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 62,
                child: Text(
                  sound.devanagari,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Sanskrit',
                    fontSize: 43,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sound.iast,
                      style: const TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _t(
                        sound.description,
                        sound.group == 'vowel'
                            ? 'Vowel reference'
                            : 'Sound reference',
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _t(
                sound.hint,
                'Tap a letter to hear its reference recording. Use normal speed when comparing vowel length.',
              ),
              style: const TextStyle(fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Wrap(
            spacing: 10,
            children: [
              FilterChip(
                label: Text(_t('慢速 0.75×', 'Slow 0.75×')),
                selected: _slow,
                onSelected: (value) {
                  _stop();
                  setState(() => _slow = value);
                },
              ),
              FilterChip(
                label: Text(_t('重复 3 次', 'Repeat 3 times')),
                selected: _repeat,
                onSelected: (value) {
                  _stop();
                  setState(() => _repeat = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('sanskrit-play-stop'),
              onPressed: busy ? _stop : () => _play(sound),
              icon: Icon(busy ? Icons.stop_rounded : Icons.volume_up_rounded),
              label: Text(
                busy ? _t('停止播放', 'Stop') : _t('播放发音', 'Play pronunciation'),
              ),
            ),
          ),
          Text(
            _cached.contains(sound.id)
                ? _t('该录音已下载，可离线播放', 'This recording is available offline')
                : _t(
                    '首次播放需联网，成功下载后可离线听读',
                    'First play requires internet; downloaded recordings work offline',
                  ),
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
