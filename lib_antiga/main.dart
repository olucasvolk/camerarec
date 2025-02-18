import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as thumbnail;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(availableCameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> availableCameras;

  const MyApp({Key? key, required this.availableCameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sports Recorder',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFE50914),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: SegmentedVideoPage(availableCameras: availableCameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RecentVideo {
  final String path;
  final DateTime timestamp;
  String? thumbnailPath;

  RecentVideo({
    required this.path,
    required this.timestamp,
    this.thumbnailPath,
  });
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;

  const VideoPlayerScreen({Key? key, required this.videoPath})
      : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.file(File(widget.videoPath));
    await _videoPlayerController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
    setState(() {});
  }

  Future<void> _shareVideo() async {
    await Share.shareXFiles([XFile(widget.videoPath)],
        text: 'Confira meu vídeo!');
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareVideo,
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: _chewieController != null
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(),
          ),
          Positioned(
            left: 26,
            top: 0,
            child: Image.asset(
              'assets/logo.png',
              width: 150,
              height: 150,
            ),
          ),
        ],
      ),
    );
  }
}

class SegmentedVideoPage extends StatefulWidget {
  final List<CameraDescription> availableCameras;

  const SegmentedVideoPage({Key? key, required this.availableCameras})
      : super(key: key);

  @override
  State<SegmentedVideoPage> createState() => _SegmentedVideoPageState();
}

class _SegmentedVideoPageState extends State<SegmentedVideoPage>
    with WidgetsBindingObserver {
  late List<CameraDescription> _availableCameras;
  late CameraController _cameraController;
  late CameraDescription _currentCamera;
  bool _isSystemVolumeChange =
      false; // Novo campo para controlar a origem da mudança

  bool _isRecording = false;
  Timer? _segmentTimer;
  Timer? _volumeTimer; // Timer para controle periódico do volume
  final List<String> _videoSegments = [];
  late Directory _tempDir;
  final int _segmentDuration = 5;
  final int _maxSegments = 6;
  DateTime _lastVolumePress = DateTime.now();

  final List<RecentVideo> _recentVideos = [];
  bool _isShowingRecents = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _availableCameras = widget.availableCameras;
    _currentCamera = _availableCameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _availableCameras.first,
    );
    _initAll();
    _startVolumeTimer(); // Inicia o timer de volume
  }

  void _startVolumeTimer() {
    _volumeTimer?.cancel();
    _volumeTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        _isSystemVolumeChange = true; // Indica que é uma mudança do sistema
        await FlutterVolumeController.setVolume(0.5);
        // Aguarda um pouco para garantir que o listener não será acionado
        await Future.delayed(const Duration(milliseconds: 100));
        _isSystemVolumeChange = false;
        debugPrint('Volume ajustado para 50%');
      } catch (e) {
        debugPrint('Erro ao ajustar volume: $e');
        _isSystemVolumeChange = false;
      }
    });
  }

  Future<void> _initVolumeController() async {
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      await FlutterVolumeController.setVolume(0.5);
      FlutterVolumeController.removeListener();

      FlutterVolumeController.addListener((volume) {
        if (_isSystemVolumeChange) {
          debugPrint('Ignorando mudança de volume do sistema');
          return;
        }

        final now = DateTime.now();
        if (now.difference(_lastVolumePress).inMilliseconds > 500) {
          _lastVolumePress = now;
          debugPrint('Volume alterado pelo usuário: $volume');
          _cutLast25Seconds();
        }
      });

      debugPrint('Controlador de volume inicializado com sucesso');
    } catch (e) {
      debugPrint('Erro ao inicializar controlador de volume: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initVolumeController();
      _startVolumeTimer();
    }
  }

  Future<void> _initAll() async {
    await _requestPermissions();
    await _initCamera();
    await _initVolumeController();
    _tempDir = await getTemporaryDirectory();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _initCamera() async {
    _cameraController = CameraController(
      _currentCamera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _cameraController.initialize();
      setState(() {});
    } catch (e) {
      debugPrint('Erro ao inicializar câmera: $e');
    }
  }

  Future<void> _generateThumbnail(RecentVideo video) async {
    try {
      final videoFile = File(video.path);
      final videoPlayerController = VideoPlayerController.file(videoFile);
      await videoPlayerController.initialize();
      final duration = videoPlayerController.value.duration;
      await videoPlayerController.dispose();

      final thumbnailPath = await thumbnail.VideoThumbnail.thumbnailFile(
        video: video.path,
        thumbnailPath: _tempDir.path,
        imageFormat: thumbnail.ImageFormat.JPEG,
        timeMs: duration.inMilliseconds,
        quality: 75,
      );

      if (thumbnailPath != null) {
        setState(() {
          video.thumbnailPath = thumbnailPath;
        });
      }
    } catch (e) {
      debugPrint('Erro ao gerar thumbnail: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2) return;

    final lensDirection = _currentCamera.lensDirection;
    CameraDescription newCamera;

    if (lensDirection == CameraLensDirection.front) {
      newCamera = _availableCameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
    } else {
      newCamera = _availableCameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
    }

    await _cameraController.dispose();
    setState(() {
      _currentCamera = newCamera;
    });
    await _initCamera();
  }

  Future<void> _startSegmentedRecording() async {
    if (!_cameraController.value.isInitialized) {
      debugPrint('Câmera não inicializada');
      return;
    }

    setState(() {
      _isRecording = true;
    });

    try {
      _videoSegments.clear();
      await _startNewSegment();

      _segmentTimer = Timer.periodic(
        Duration(seconds: _segmentDuration),
        (timer) async {
          await _rotateSegment();
        },
      );
    } catch (e) {
      debugPrint('Erro ao iniciar gravação: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _startNewSegment() async {
    try {
      debugPrint('Iniciando novo segmento');
      await _cameraController.startVideoRecording();
      debugPrint('Segmento iniciado com sucesso');
    } catch (e) {
      debugPrint('Erro ao iniciar gravação de segmento: $e');
      throw e;
    }
  }

  Future<void> _rotateSegment() async {
    if (!_cameraController.value.isRecordingVideo) {
      debugPrint('Não está gravando vídeo');
      return;
    }

    try {
      debugPrint('Rotacionando segmento');
      final xFile = await _cameraController.stopVideoRecording();
      _videoSegments.add(xFile.path);
      debugPrint('Segmento salvo: ${xFile.path}');

      if (_videoSegments.length > _maxSegments) {
        final removed = _videoSegments.removeAt(0);
        await _deleteFileIfExists(removed);
      }

      await _startNewSegment();
    } catch (e) {
      debugPrint('Erro ao rotacionar segmento: $e');
    }
  }

  Future<void> _stopSegmentedRecording() async {
    _segmentTimer?.cancel();
    _segmentTimer = null;
    if (_cameraController.value.isRecordingVideo) {
      final xFile = await _cameraController.stopVideoRecording();
      _videoSegments.add(xFile.path);
      if (_videoSegments.length > _maxSegments) {
        final removed = _videoSegments.removeAt(0);
        await _deleteFileIfExists(removed);
      }
    }
    setState(() {
      _isRecording = false;
    });
  }

  Future<void> _deleteFileIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _createFinalVideoExactly25s(String inputPath) async {
    final double targetDuration = 25.0;
    final trimmedPath =
        '${_tempDir.path}/final25s_${DateTime.now().millisecondsSinceEpoch}.mp4';

    Duration? videoDuration = await _getVideoDuration(inputPath);
    if (videoDuration == null) {
      debugPrint('Não foi possível obter a duração do vídeo.');
      return;
    }

    String cmdCut;
    if (videoDuration.inSeconds > 25) {
      // Se o vídeo for maior que 25s, pega os últimos 25 segundos
      final startTime = videoDuration.inSeconds - 25;
      cmdCut =
          "-i '$inputPath' -ss $startTime -t $targetDuration -c copy '$trimmedPath'";
    } else {
      // Se for menor ou igual a 25s, mantém o vídeo como está
      cmdCut = "-i '$inputPath' -c copy '$trimmedPath'";
    }

    final sessionCut = await FFmpegKit.execute(cmdCut);
    final rcCut = await sessionCut.getReturnCode();

    if (ReturnCode.isSuccess(rcCut)) {
      debugPrint('Corte para 25s concluído em: $trimmedPath');
      final success = await GallerySaver.saveVideo(trimmedPath);
      debugPrint('Vídeo 25s salvo na galeria? $success');

      final recentVideo = RecentVideo(
        path: trimmedPath,
        timestamp: DateTime.now(),
      );

      setState(() {
        _recentVideos.insert(0, recentVideo);
        if (_recentVideos.length > 10) {
          _recentVideos.removeLast();
        }
      });

      await _generateThumbnail(recentVideo);
    } else {
      debugPrint('Erro no corte de 25s: $rcCut');
    }
  }

  Future<Duration?> _getVideoDuration(String path) async {
    try {
      final ctrl = VideoPlayerController.file(File(path));
      await ctrl.initialize();
      final d = ctrl.value.duration;
      await ctrl.dispose();
      return d;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cutLast25Seconds() async {
    if (!_isRecording && _videoSegments.isEmpty) {
      debugPrint('Nenhum bloco gravado ainda!');
      return;
    }

    try {
      if (_cameraController.value.isRecordingVideo) {
        final xFile = await _cameraController.stopVideoRecording();
        _videoSegments.add(xFile.path);
        debugPrint('Segmento atual adicionado: ${xFile.path}');

        if (_videoSegments.length > _maxSegments) {
          final removed = _videoSegments.removeAt(0);
          await _deleteFileIfExists(removed);
        }

        if (_isRecording) {
          await _startNewSegment();
        }
      }

      if (_videoSegments.isEmpty) {
        debugPrint('Nenhum segmento disponível para corte');
        return;
      }

      final listFilePath =
          '${_tempDir.path}/segments_${DateTime.now().millisecondsSinceEpoch}.txt';
      final listFile = File(listFilePath);
      final sb = StringBuffer();

      for (var segPath in _videoSegments) {
        sb.writeln("file '$segPath'");
      }
      await listFile.writeAsString(sb.toString());
      debugPrint('Arquivo de lista criado: $listFilePath');

      final concatenatedPath =
          '${_tempDir.path}/concat_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final ffmpegCmd =
          "-f concat -safe 0 -i '$listFilePath' -c copy '$concatenatedPath'";
      debugPrint('Executando FFmpeg: $ffmpegCmd');

      FFmpegSession session = await FFmpegKit.execute(ffmpegCmd);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('Concat OK! Arquivo gerado: $concatenatedPath');
        await _createFinalVideoExactly25s(concatenatedPath);
      } else {
        debugPrint('Erro no FFmpeg ao concatenar. Return code: $returnCode');
      }

      await _deleteFileIfExists(listFilePath);
    } catch (e) {
      debugPrint('Erro ao cortar vídeo: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterVolumeController.removeListener();
    _segmentTimer?.cancel();
    _volumeTimer?.cancel(); // Cancela o timer de volume
    _cameraController.dispose();
    super.dispose();
  }

  Widget _buildRecentVideos() {
    if (_recentVideos.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.0),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              'Vídeos Recentes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentVideos.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                final video = _recentVideos[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          videoPath: video.path,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (video.thumbnailPath != null)
                              Image.file(
                                File(video.thumbnailPath!),
                                fit: BoxFit.cover,
                              )
                            else
                              Container(
                                color: Colors.grey[900],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sports Recorder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_camera),
            tooltip: "Trocar Câmera",
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _cameraController.value.aspectRatio,
              child: CameraPreview(_cameraController),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: _buildRecentVideos(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isRecording ? Colors.red : const Color(0xFFE50914),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isRecording
                  ? _stopSegmentedRecording
                  : _startSegmentedRecording,
              icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
              label: Text(_isRecording ? 'Parar' : 'Iniciar'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF564D4D),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _cutLast25Seconds,
              icon: const Icon(Icons.content_cut),
              label: const Text('Cortar 25s'),
            ),
          ),
        ],
      ),
    );
  }
}
