import 'package:flutter/material.dart';
import '../controllers/recorder_controller.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/cut_button.dart';
import '../widgets/record_button.dart';

class RecordingScreen extends StatefulWidget {
  final RecorderController controller;

  const RecordingScreen({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    widget.controller.disposeVolumeControl();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await widget.controller.initializeCamera();
      await widget.controller.initializeVolumeControl();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (widget.controller.isRecording) {
                widget.controller.stopSegmentedRecording();
              }
              Navigator.of(context).pop();
            },
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: widget.controller.switchCamera,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isLoading)
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE50914),
                ),
              ),
            )
          else ...[
            CameraPreviewWidget(controller: widget.controller),
            Positioned(
              right: 16,
              bottom: 100,
              child: CutButton(controller: widget.controller),
            ),
            Positioned(
              left: 16,
              top: 80,
              child: Image.asset(
                'assets/logo.png',
                width: 80,
                height: 80,
              ),
            ),
          ],
        ],
      ),
      floatingActionButton:
          !_isLoading ? RecordButton(controller: widget.controller) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
