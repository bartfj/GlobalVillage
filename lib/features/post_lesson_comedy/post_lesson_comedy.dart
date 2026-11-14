import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_strings.dart';
import 'comedy_catalog.dart';

class PostLessonComedy extends StatefulWidget {
  const PostLessonComedy({
    super.key,
    required this.courseId,
    required this.lessonId,
    required this.strings,
    required this.onFinished,
  });

  final String courseId, lessonId;
  final S strings;
  final VoidCallback onFinished;

  @override
  State<PostLessonComedy> createState() => _PostLessonComedyState();
}

class _PostLessonComedyState extends State<PostLessonComedy>
    with WidgetsBindingObserver {
  ComedyCatalog? _catalog;
  ComedyEpisode? _episode;
  MethodChannel? _channel;
  Timer? _timer;
  Timer? _initializationTimeout;
  int _line = 0;
  int _viewGeneration = 0;
  bool _loading = true, _error = false, _exited = false;
  bool _playing = true, _completed = false, _chinese = true;
  bool _backgroundPaused = false;
  bool _appActive = true;

  bool get _native =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final catalog = await ComedyCatalog.load();
      if (!mounted || _exited) return;
      final episode = catalog.recommend(widget.courseId, widget.lessonId);
      if (episode == null || episode.lines.isEmpty) {
        _finish();
        return;
      }
      setState(() {
        _catalog = catalog;
        _episode = episode;
        _loading = _native;
        _error = false;
      });
      if (_native) {
        _startInitializationTimeout();
      } else {
        _schedule();
      }
    } catch (_) {
      if (mounted && !_exited)
        setState(() {
          _loading = false;
          _error = true;
        });
    }
  }

  void _startInitializationTimeout() {
    _initializationTimeout?.cancel();
    _initializationTimeout = Timer(const Duration(seconds: 12), () {
      if (!mounted || _exited) return;
      unawaited(_send('stop'));
      setState(() {
        _loading = false;
        _error = true;
        _playing = false;
      });
    });
  }

  void _attach(int viewId) {
    final channel = MethodChannel('globalvillage/comedy/$viewId');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted || _exited || _channel != channel || call.method != 'event')
        return;
      switch (call.arguments) {
        case 'ready':
          _initializationTimeout?.cancel();
          setState(() {
            _loading = false;
            _error = false;
            _completed = false;
            if (_appActive) _backgroundPaused = false;
          });
          if (_backgroundPaused) await _send('pause');
        case 'completed':
          setState(() {
            _completed = true;
            _playing = false;
          });
        case 'error':
          _initializationTimeout?.cancel();
          setState(() {
            _loading = false;
            _error = true;
            _playing = false;
          });
      }
    });
  }

  Future<void> _send(String command) async {
    try {
      await _channel?.invokeMethod<void>(command);
    } on PlatformException {
      if (mounted && !_exited && command != 'stop') {
        setState(() {
          _loading = false;
          _error = true;
          _playing = false;
        });
      }
    } on MissingPluginException {
      if (mounted && !_exited && command != 'stop') {
        setState(() {
          _loading = false;
          _error = true;
          _playing = false;
        });
      }
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!_playing || _completed || _exited || _native) return;
    final line = _episode!.lines[_line];
    _timer = Timer(
      Duration(milliseconds: (line.duration * 1000).ceil() + 650),
      () {
        if (!mounted || !_playing || _exited) return;
        _advance();
        _schedule();
      },
    );
  }

  void _advance() {
    setState(() {
      if (_line + 1 < _episode!.lines.length) {
        _line++;
      } else {
        _completed = true;
        _playing = false;
      }
    });
  }

  void _move(int delta) {
    _timer?.cancel();
    _playing = false;
    if (delta > 0) {
      _advance();
    } else {
      setState(() {
        _line = (_line - 1).clamp(0, _episode!.lines.length - 1);
        _completed = false;
      });
    }
  }

  void _togglePlayback() {
    setState(() {
      _playing = !_playing;
      _backgroundPaused = false;
    });
    if (_native) {
      unawaited(_send(_playing ? 'play' : 'pause'));
    } else {
      _schedule();
    }
  }

  void _replay() {
    _timer?.cancel();
    setState(() {
      _line = 0;
      _completed = false;
      _playing = true;
      _backgroundPaused = false;
    });
    if (_native) {
      unawaited(_send('replay'));
    } else {
      _schedule();
    }
  }

  void _retry() {
    _timer?.cancel();
    _channel?.setMethodCallHandler(null);
    unawaited(_send('stop'));
    _channel = null;
    setState(() {
      _viewGeneration++;
      _line = 0;
      _error = false;
      _loading = _native;
      _playing = true;
      _completed = false;
      _backgroundPaused = false;
    });
    if (_episode == null) {
      unawaited(_load());
    } else if (_native) {
      _startInitializationTimeout();
    } else {
      _schedule();
    }
  }

  void _finish() {
    if (_exited) return;
    _exited = true;
    _timer?.cancel();
    _initializationTimeout?.cancel();
    unawaited(_send('stop'));
    widget.onFinished();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (_appActive || _exited) return;
    _timer?.cancel();
    unawaited(_send('pause'));
    setState(() {
      _playing = false;
      _backgroundPaused = true;
    });
  }

  @override
  void dispose() {
    _exited = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _initializationTimeout?.cancel();
    unawaited(_send('stop'));
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight:
              56 *
              (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1, 2),
          title: Text(
            s.comedyTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            SizedBox(
              width: MediaQuery.sizeOf(context).width * .48,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  s.comedySkip,
                  maxLines: 3,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_backgroundPaused)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(s.comedyBackgroundPaused),
                ),
              Expanded(child: _body(context)),
              if (_completed)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _replay,
                        child: Text(s.comedyReplay),
                      ),
                      FilledButton(
                        onPressed: _finish,
                        child: Text(s.comedyContinue),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final s = widget.strings;
    if (_error)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.comedyLoadFailed),
              const SizedBox(height: 12),
              FilledButton(onPressed: _retry, child: Text(s.comedyRetry)),
            ],
          ),
        ),
      );
    if (_episode == null) return Center(child: Text(s.comedyLoading));
    if (_native)
      return Stack(
        children: [
          AndroidView(
            key: ValueKey(_viewGeneration),
            viewType: 'globalvillage/post-lesson-comedy',
            creationParams: {
              'scene': _episode!.id,
              'english': s.isEn,
              'reducedMotion': MediaQuery.disableAnimationsOf(context),
              'chinese': _chinese,
              'textZoom':
                  (MediaQuery.textScalerOf(context).scale(16) / 16 * 100)
                      .round()
                      .clamp(80, 250),
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _attach,
          ),
          if (_loading)
            ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Center(child: Text(s.comedyLoading)),
            ),
        ],
      );
    final episode = _episode!;
    final line = episode.lines[_line];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: episode.id,
            isExpanded: true,
            items: _catalog!.episodes
                .map(
                  (e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(s.isEn ? e.titleEn : e.title, maxLines: 2),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id == null) return;
              _timer?.cancel();
              setState(() {
                _episode = _catalog!.episodes.firstWhere((e) => e.id == id);
                _line = 0;
                _playing = false;
                _completed = false;
              });
            },
          ),
          const SizedBox(height: 20),
          Text(
            '${s.isEn ? (line.speaker == '艾米' ? 'Amy' : 'Tom') : line.speaker} · ${_line + 1}/${episode.lines.length}',
          ),
          const SizedBox(height: 12),
          Text(line.english, style: Theme.of(context).textTheme.headlineSmall),
          if (_chinese)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(line.chinese),
            ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _line > 0 ? () => _move(-1) : null,
                child: Text(s.comedyPreviousLine),
              ),
              FilledButton(
                key: const ValueKey('comedy-play-pause'),
                onPressed: _completed ? _replay : _togglePlayback,
                child: Text(
                  _completed
                      ? s.comedyReplay
                      : _playing
                      ? s.comedyPause
                      : s.comedyPlay,
                ),
              ),
              OutlinedButton(
                onPressed: _completed ? null : () => _move(1),
                child: Text(s.comedyNextLine),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.comedySubtitles),
            value: _chinese,
            onChanged: (value) => setState(() => _chinese = value),
          ),
        ],
      ),
    );
  }
}
