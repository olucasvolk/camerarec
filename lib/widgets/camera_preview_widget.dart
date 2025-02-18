import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../controllers/recorder_controller.dart';

class CameraPreviewWidget extends StatefulWidget {
  final RecorderController controller;

  const CameraPreviewWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _flashAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flashController,
      curve: Curves.easeIn,
      reverseCurve: Curves.easeOut,
    ));

    widget.controller.addListener(_handleControllerUpdate);
  }

  void _handleControllerUpdate() {
    if (widget.controller.recentVideos.isNotEmpty) {
      final latestVideo = widget.controller.recentVideos.first;
      final now = DateTime.now();
      if (now.difference(latestVideo.timestamp).inMilliseconds < 500) {
        _showFlash();
      }
    }
  }

  void _showFlash() {
    _flashController.forward().then((_) {
      _flashController.reverse();
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _flashController.dispose();
    widget.controller.removeListener(_handleControllerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        if (!widget.controller.isInitialized ||
            widget.controller.cameraController == null) {
          return Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE50914),
              ),
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Transform.scale(
                scale: 1.1,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1 /
                        widget.controller.cameraController!.value.aspectRatio,
                    child: CameraPreview(widget.controller.cameraController!),
                  ),
                ),
              ),
            ),
            if (widget.controller.isRecording)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'REC',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(
                                widget.controller.recordingDuration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            FadeTransition(
              opacity: _flashAnimation,
              child: Container(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        );
      },
    );
  }
}
