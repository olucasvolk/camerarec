import 'package:flutter/material.dart';
import '../controllers/recorder_controller.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/cut_button.dart';

class CameraScreen extends StatelessWidget {
  final RecorderController controller;

  const CameraScreen({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreviewWidget(controller: controller),
        Positioned(
          right: 16,
          top: 0,
          bottom: 0,
          child: Center(
            child: CutButton(controller: controller),
          ),
        ),
        Positioned(
          left: 16,
          top: 16,
          child: Image.asset(
            'assets/logo.png',
            width: 80,
            height: 80,
          ),
        ),
      ],
    );
  }
}
