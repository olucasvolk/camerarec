import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/recent_video.dart';
import '../widgets/video_feed_item.dart';
import '../controllers/recorder_controller.dart';

class VideoFeedScreen extends StatefulWidget {
  final List<RecentVideo> videos;
  final RecorderController controller;
  final int initialIndex;

  const VideoFeedScreen({
    Key? key,
    required this.videos,
    required this.controller,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        itemCount: widget.videos.length,
        itemBuilder: (context, index) {
          return VideoFeedItem(
            video: widget.videos[index],
            isActive: _currentPage == index,
            controller: widget.controller,
            autoPlay: true,
          );
        },
      ),
    );
  }
}
