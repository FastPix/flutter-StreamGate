import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/app_logger.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String? playbackId;

  const VideoPlayerScreen({
    super.key,
    this.playbackId,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? videoController;
  ChewieController? chewieController;

  bool isLoading = true;
  bool hasError = false;

  int retryCount = 0;
  final int maxRetries = 3;

  
  // VIDEO STREAM URL (FOR PLAYER ONLY)

  String getStreamUrl() {
    if (widget.playbackId == null || widget.playbackId!.isEmpty) {
      throw Exception("PlaybackId missing");
    }

    return "https://stream.fastpix.io/${widget.playbackId}.m3u8";
  }

  
  // SHARE URL (FOR WHATSAPP / CHROME / WEB)
  
  String getShareUrl() {
    if (widget.playbackId == null || widget.playbackId!.isEmpty) {
      throw Exception("PlaybackId missing");
    }

    return "https://play.fastpix.io/?playbackId=${widget.playbackId}"
        "&muted=false"
        "&hide-controls=false"
        "&accent-color=ff6100"
        "&primary-color=ffffff";
  }

  
  // INIT PLAYER
  
  Future<void> initializePlayer() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final url = getStreamUrl();

      AppLogger.log("🎬 STREAM URL: $url");

      videoController?.dispose();
      chewieController?.dispose();

      videoController = VideoPlayerController.networkUrl(
        Uri.parse(url),
      );

      await videoController!.initialize();

      chewieController = ChewieController(
        videoPlayerController: videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
        hasError = false;
      });
    } catch (e) {
      AppLogger.log("❌ Player error: $e");

      retryCount++;

      if (retryCount < maxRetries) {
        await Future.delayed(
          const Duration(seconds: 3),
        );

        return initializePlayer();
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  
  // COPY SHARE URL
  
  void copyUrl() {
    Clipboard.setData(
      ClipboardData(
        text: getShareUrl(),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Share URL Copied"),
      ),
    );
  }

  
  // SHARE VIDEO
  
  Future<void> shareUrl() async {
    await Share.share(
      getShareUrl(),
      subject: "Watch this video",
    );
  }

  @override
  void initState() {
    super.initState();
    initializePlayer();
  }

  @override
  void dispose() {
    videoController?.dispose();
    chewieController?.dispose();

    super.dispose();
  }

  
  // PLAYER UI
  
  Widget buildPlayer() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (hasError ||
        videoController == null ||
        !videoController!.value.isInitialized ||
        chewieController == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Video failed to load",
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              retryCount = 0;
              initializePlayer();
            },
            child: const Text("Retry"),
          ),
        ],
      );
    }

    return Chewie(
      controller: chewieController!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Playback"),
      ),
      body: Column(
        children: [
          Expanded(
            child: buildPlayer(),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "Playback ID:\n${widget.playbackId}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  getShareUrl(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: copyUrl,
                      icon: const Icon(Icons.copy),
                      label: const Text("Copy"),
                    ),
                    ElevatedButton.icon(
                      onPressed: shareUrl,
                      icon: const Icon(Icons.share),
                      label: const Text("Share"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Back"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
