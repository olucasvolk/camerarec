import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recent_video.dart';
import '../screens/profile_screen.dart';
import '../controllers/recorder_controller.dart';

class VideoFeedItem extends StatefulWidget {
  final RecentVideo video;
  final bool isActive;
  final RecorderController controller;
  final bool autoPlay;

  const VideoFeedItem({
    Key? key,
    required this.video,
    required this.isActive,
    required this.controller,
    this.autoPlay = true,
  }) : super(key: key);

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      _updatePlaybackState();
    }
  }

  void _updatePlaybackState() {
    if (!_isInitialized || _controller == null) return;

    if (widget.isActive) {
      _controller!.setVolume(1.0);
      _controller!.play();
    } else {
      _controller!.pause();
      _controller!.setVolume(0.0);
    }
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(File(widget.video.path));
    try {
      await _controller!.initialize();
      _controller!.setLooping(true);
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });

      if (widget.isActive && widget.autoPlay) {
        _controller!.setVolume(1.0);
        _controller!.play();
      } else {
        _controller!.setVolume(0.0);
      }
    } catch (e) {
      print('Erro ao inicializar vídeo: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteVideo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Excluir vídeo',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tem certeza que deseja excluir este vídeo?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.controller.deleteVideo(widget.video);
      if (mounted) {
        Navigator.of(context).pop(); // Fecha a tela após excluir
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFE50914),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_isInitialized || _controller == null)
          widget.video.thumbnailPath != null
              ? Image.file(
                  File(widget.video.thumbnailPath!),
                  fit: BoxFit.cover,
                )
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(
                      Icons.video_library,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                )
        else
          GestureDetector(
            onTap: () {
              if (_controller!.value.isPlaying) {
                _controller!.pause();
              } else {
                _controller!.play();
              }
            },
            child: Stack(
              children: [
                VideoPlayer(_controller!),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFFE50914),
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white12,
                    ),
                    padding: const EdgeInsets.only(top: 4),
                  ),
                ),
              ],
            ),
          ),
        _buildOverlay(),
        _buildSideBar(),
      ],
    );
  }

  Widget _buildOverlay() {
    return Positioned(
      left: 16,
      right: 96,
      bottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                child: const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFE50914),
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '@usuario',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Seguir',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatTimestamp(widget.video.timestamp),
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideBar() {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        children: [
          _buildSideBarButton(
            Icons.favorite,
            '1.2K',
            () {},
          ),
          const SizedBox(height: 20),
          _buildSideBarButton(
            Icons.comment,
            '234',
            () {},
          ),
          const SizedBox(height: 20),
          _buildSideBarButton(
            Icons.share,
            'Share',
            () {
              Share.shareXFiles(
                [XFile(widget.video.path)],
                text: 'Confira meu vídeo!',
              );
            },
          ),
          const SizedBox(height: 20),
          _buildSideBarButton(
            Icons.delete,
            'Excluir',
            _deleteVideo,
          ),
        ],
      ),
    );
  }

  Widget _buildSideBarButton(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.5),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m atrás';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h atrás';
    } else {
      return '${difference.inDays}d atrás';
    }
  }
}
