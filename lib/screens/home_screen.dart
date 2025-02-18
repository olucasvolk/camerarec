import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../controllers/recorder_controller.dart';
import 'recording_screen.dart';
import 'gallery_screen.dart';
import 'plans_screen.dart';
import '../widgets/bottom_navigation.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> availableCameras;

  const HomeScreen({Key? key, required this.availableCameras})
      : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final RecorderController _controller;
  int _selectedIndex = 0; // Começa na galeria

  @override
  void initState() {
    super.initState();
    _controller = RecorderController(widget.availableCameras);
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    await _controller.loadSavedVideos();
  }

  void _handleTabChange(int index) {
    if (index == 1) {
      // Abre a tela de gravação
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RecordingScreen(
            controller: _controller,
          ),
        ),
      );
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          GalleryScreen(controller: _controller),
          Container(), // Placeholder para o índice da câmera
          const PlansScreen(),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: _selectedIndex,
        onTap: _handleTabChange,
      ),
    );
  }
}
