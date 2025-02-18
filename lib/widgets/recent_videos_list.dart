import 'package:flutter/material.dart';
import '../controllers/recorder_controller.dart';
import '../screens/video_feed_screen.dart';

class RecentVideosList extends StatefulWidget {
  final RecorderController controller;

  const RecentVideosList({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<RecentVideosList> createState() => _RecentVideosListState();
}

class _RecentVideosListState extends State<RecentVideosList> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        if (widget.controller.recentVideos.isEmpty) {
          return const Center(
            child: Text(
              'Nenhum vídeo gravado ainda',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          );
        }

        return VideoFeedScreen(
          videos: widget.controller.recentVideos,
          controller: widget.controller,
          initialIndex: 0, // Começa pelo primeiro vídeo
        );
      },
    );
  }
}
