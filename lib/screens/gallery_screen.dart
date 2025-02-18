import 'package:flutter/material.dart';
import '../controllers/recorder_controller.dart';
import '../screens/video_feed_screen.dart';
import '../widgets/video_thumbnail.dart';

class GalleryScreen extends StatefulWidget {
  final RecorderController controller;

  const GalleryScreen({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    await widget.controller.loadSavedVideos();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openVideoFeed(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoFeedScreen(
          videos: widget.controller.recentVideos,
          controller: widget.controller,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF000000),
          ],
        ),
      ),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE50914),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFFE50914),
              backgroundColor: Colors.black,
              onRefresh: _loadVideos,
              child: widget.controller.recentVideos.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 300),
                        Center(
                          child: Text(
                            'Nenhum vídeo gravado ainda',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 9 / 16,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: widget.controller.recentVideos.length,
                      itemBuilder: (context, index) {
                        final video = widget.controller.recentVideos[index];
                        return GestureDetector(
                          onTap: () => _openVideoFeed(index),
                          child: VideoThumbnail(video: video),
                        );
                      },
                    ),
            ),
    );
  }
}
