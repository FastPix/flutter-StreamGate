import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/screen_record_service.dart';

/// ScreenRecordScreen
///
/// Navigation contract (matches RecordScreen.openScreenRecorder):
///   • On success  → Navigator.pop(context, filePath)
///   • On cancel   → Navigator.pop(context, null)
///
/// The upload flow is triggered by RecordScreen after this screen pops,
/// so this screen never pushes UploadScreen directly.
class ScreenRecordScreen extends StatefulWidget {
  const ScreenRecordScreen({super.key});

  @override
  State<ScreenRecordScreen> createState() => _ScreenRecordScreenState();
}

class _ScreenRecordScreenState extends State<ScreenRecordScreen>
    with WidgetsBindingObserver {
  final _service = ScreenRecordService();

  bool _isRecording = false;
  bool _isStopping  = false;   // brief spinner while Android stop() is in-flight

  // Duration counter
  Timer? _durationTimer;
  int   _secondsElapsed = 0;

  // iOS-only polling after the broadcast extension finishes
  Timer? _pollTimer;
  int    _pollCount = 0;
  bool   _isPolling = false;
  static const _pollInterval  = Duration(seconds: 2);
  static const _maxPollCount  = 40; // 80-second window

  // Lifecycle 
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isIOS) _checkOnce();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // iOS: when user returns from the system broadcast extension, start polling
    if (state == AppLifecycleState.resumed && _isRecording && Platform.isIOS) {
      _startIosPolling();
    }
  }

  // iOS: check for a leftover finished recording from a previous session 
  Future<void> _checkOnce() async {
    final path = await _service.checkRecordingReady();
    if (path != null && mounted) _finishWithPath(path);
  }

  //  Duration timer 
  void _startTimer() {
    _secondsElapsed = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  void _stopTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  String get _timerLabel {
    final m = _secondsElapsed ~/ 60;
    final s = _secondsElapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // iOS polling 
  void _startIosPolling() {
    if (_isPolling || !mounted) return;
    _pollCount = 0;
    setState(() => _isPolling = true);

    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      if (!mounted) { _pollTimer?.cancel(); return; }
      _pollCount++;

      final path = await _service.checkRecordingReady();
      if (!mounted) { _pollTimer?.cancel(); return; }

      if (path != null) {
        _pollTimer?.cancel();
        setState(() => _isPolling = false);
        _finishWithPath(path);
        return;
      }

      if (_pollCount >= _maxPollCount) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() => _isPolling = false);
          _showSnack('No recording found. Please try again.');
        }
      }
    });
  }

  //  Start / Stop 
  Future<void> _onStart() async {
    await _service.startRecording();
    if (!mounted) return;
    setState(() => _isRecording = true);
    _startTimer();
    if (Platform.isAndroid) {
      _showSnack('Screen recording started.');
    } else {
      _showSnack('Tap "Start Broadcast" in the picker to begin.');
    }
  }

  Future<void> _onStop() async {
    if (!mounted) return;
    _stopTimer();
    setState(() {
      _isRecording = false;
      _isStopping  = true;
    });

    final path = await _service.stopRecording();

    if (!mounted) return;
    setState(() => _isStopping = false);

    if (Platform.isAndroid) {
      if (path != null && path.isNotEmpty) {
        _finishWithPath(path);
      } else {
        _showSnack('Recording failed to save. Please try again.');
      }
    } else {
      // iOS: path arrives asynchronously via the App Group
      _startIosPolling();
    }
  }

  // Pop back to RecordScreen with the file path 
  void _finishWithPath(String path) {
    if (!mounted) return;
    _service.clearRecording(); // no-op on Android
    Navigator.of(context).pop(path);
  }

  // Snack 
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
    );
  }

  // Build 
  Widget build(BuildContext context) {
    final theme      = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Screen Recorder')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status icon / spinner 
              if (_isStopping || _isPolling)
                const SizedBox(
                  width: 72, height: 72,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else if (_isRecording)
                _RecordingPulse(color: colorScheme.error)
              else
                Icon(
                  Icons.screen_share_rounded,
                  size: 72,
                  color: colorScheme.primary,
                ),

              const SizedBox(height: 32),

              // Label 
              if (_isStopping || _isPolling) ...[
                Text('recording…',
                  style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Please wait',
                  style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ] else if (_isRecording) ...[
                Text(_timerLabel,
                  style: theme.textTheme.displaySmall
                    ?.copyWith(fontFeatures: [const FontFeature.tabularFigures()])),
                const SizedBox(height: 8),
                Text('Recording in progress',
                  style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ] else ...[
                Text('Screen Recorder',
                  style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  Platform.isIOS
                    ? 'Records your screen via the system broadcast extension.'
                    : 'Records your screen using Android MediaProjection.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],

              const SizedBox(height: 40),

              // Action button 
              if (!_isStopping && !_isPolling)
                SizedBox(
                  width: double.infinity,
                  child: _isRecording
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _onStop,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Stop Recording',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _onStart,
                        icon: const Icon(Icons.fiber_manual_record_rounded),
                        label: const Text('Start Recording',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple animated pulsing record dot
class _RecordingPulse extends StatefulWidget {
  final Color color;
  const _RecordingPulse({required this.color});

  @override
  State<_RecordingPulse> createState() => _RecordingPulseState();
}

class _RecordingPulseState extends State<_RecordingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_ctrl),
      child: Icon(Icons.radio_button_checked_rounded, size: 72, color: widget.color),
    );
  }
}