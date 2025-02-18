import 'dart:io';
import 'package:flutter/material.dart';
import '../controllers/recorder_controller.dart';
import '../screens/video_feed_screen.dart';

class RecordButton extends StatelessWidget {
  final RecorderController controller;

  const RecordButton({
    Key? key,
    required this.controller,
  }) : super(key: key);

  void _openGallery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoFeedScreen(
          videos: controller.recentVideos,
          controller: controller,
          initialIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (controller.recentVideos.isNotEmpty)
              GestureDetector(
                onTap: () => _openGallery(context),
                child: Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    image: controller.recentVideos.first.thumbnailPath != null
                        ? DecorationImage(
                            image: FileImage(
                              File(
                                  controller.recentVideos.first.thumbnailPath!),
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: controller.recentVideos.first.thumbnailPath == null
                      ? const Icon(
                          Icons.video_library,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 0.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, value * 100),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: controller.isRecording
                          ? const Color(0xFFE50914)
                          : Colors.black,
                      boxShadow: [
                        BoxShadow(
                          color: (controller.isRecording
                                  ? const Color(0xFFE50914)
                                  : Colors.black)
                              .withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: controller.isRecording
                            ? controller.stopSegmentedRecording
                            : controller.startSegmentedRecording,
                        child: Icon(
                          controller.isRecording ? Icons.stop : Icons.videocam,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
