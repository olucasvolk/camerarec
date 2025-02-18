import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import '../models/recent_video.dart';
import '../services/video_service.dart';

class RecorderController extends ChangeNotifier {
  static const String _videosKey = 'recent_videos';
  final List<CameraDescription> _availableCameras;
  CameraController? cameraController;
  late CameraDescription _currentCamera;
  bool isRecording = false;
  Timer? _segmentTimer;
  Timer? _recordingTimer;
  Timer? _volumeTimer;
  final List<String> videoSegments = [];
  late Directory _tempDir;
  final int segmentDuration = 5;
  final int maxSegments = 6;
  final List<RecentVideo> recentVideos = [];
  bool isInitialized = false;
  Duration recordingDuration = Duration.zero;
  DateTime _lastVolumePress = DateTime.now();
  bool _isSystemVolumeChange = false;

  RecorderController(this._availableCameras) {
    _currentCamera = _availableCameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _availableCameras.first,
    );
  }

  Future<void> initializeCamera() async {
    if (cameraController != null) {
      await cameraController!.dispose();
    }

    cameraController = CameraController(
      _currentCamera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await cameraController!.initialize();
      isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Erro ao inicializar câmera: $e');
      cameraController = null;
      isInitialized = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> initializeVolumeControl() async {
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      FlutterVolumeController.removeListener();

      FlutterVolumeController.addListener((volume) {
        if (_isSystemVolumeChange) {
          print('Ignorando mudança de volume do sistema');
          return;
        }

        final now = DateTime.now();
        if (now.difference(_lastVolumePress).inMilliseconds > 500) {
          _lastVolumePress = now;
          print('Volume alterado pelo usuário: $volume');
          cutLast25Seconds();
        }
      });

      if (isRecording) {
        await FlutterVolumeController.setVolume(0.0);
        _startVolumeTimer();
      }

      print('Controlador de volume inicializado com sucesso');
    } catch (e) {
      print('Erro ao inicializar controlador de volume: $e');
    }
  }

  void _startVolumeTimer() {
    _volumeTimer?.cancel();
    _volumeTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (isRecording) {
        try {
          _isSystemVolumeChange = true;
          await FlutterVolumeController.setVolume(0.0);
          await Future.delayed(const Duration(milliseconds: 100));
          _isSystemVolumeChange = false;
          print('Volume ajustado para 0');
        } catch (e) {
          print('Erro ao ajustar volume: $e');
          _isSystemVolumeChange = false;
        }
      }
    });
  }

  void disposeVolumeControl() {
    FlutterVolumeController.removeListener();
    _volumeTimer?.cancel();
    _volumeTimer = null;
  }

  Future<void> loadSavedVideos() async {
    try {
      await _requestPermissions();
      _tempDir = await getTemporaryDirectory();

      final prefs = await SharedPreferences.getInstance();
      final videosJson = prefs.getStringList(_videosKey) ?? [];

      recentVideos.clear();
      for (var videoJson in videosJson) {
        try {
          final videoMap = json.decode(videoJson);
          final video = RecentVideo.fromJson(videoMap);

          // Verifica se os arquivos ainda existem
          if (await File(video.path).exists() &&
              (video.thumbnailPath == null ||
                  await File(video.thumbnailPath!).exists())) {
            recentVideos.add(video);
          }
        } catch (e) {
          print('Erro ao carregar vídeo: $e');
        }
      }

      // Ordena por data, mais recente primeiro
      recentVideos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    } catch (e) {
      print('Erro ao carregar vídeos salvos: $e');
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _saveVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videosJson =
          recentVideos.map((v) => json.encode(v.toJson())).toList();
      await prefs.setStringList(_videosKey, videosJson);
    } catch (e) {
      print('Erro ao salvar vídeos: $e');
    }
  }

  Future<void> deleteVideo(RecentVideo video) async {
    try {
      // Remove o vídeo da lista
      recentVideos.remove(video);
      notifyListeners();

      // Deleta os arquivos
      await VideoService.deleteFileIfExists(video.path);
      if (video.thumbnailPath != null) {
        await VideoService.deleteFileIfExists(video.thumbnailPath!);
      }

      // Atualiza a persistência
      await _saveVideos();
    } catch (e) {
      print('Erro ao deletar vídeo: $e');
    }
  }

  void _startRecordingTimer() {
    recordingDuration = Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      recordingDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    recordingDuration = Duration.zero;
    notifyListeners();
  }

  Future<void> startSegmentedRecording() async {
    if (!isInitialized || !cameraController!.value.isInitialized) {
      print('Câmera não inicializada');
      return;
    }

    isRecording = true;
    _startRecordingTimer();
    notifyListeners();

    try {
      videoSegments.clear();
      await _startNewSegment();

      // Inicia o controle de volume
      await FlutterVolumeController.setVolume(0.0);
      _startVolumeTimer();

      _segmentTimer = Timer.periodic(
        Duration(seconds: segmentDuration),
        (timer) async {
          await _rotateSegment();
        },
      );
    } catch (e) {
      print('Erro ao iniciar gravação: $e');
      isRecording = false;
      _stopRecordingTimer();
      notifyListeners();
    }
  }

  Future<void> _startNewSegment() async {
    try {
      print('Iniciando novo segmento');
      await cameraController!.startVideoRecording();
      print('Segmento iniciado com sucesso');
    } catch (e) {
      print('Erro ao iniciar gravação de segmento: $e');
      throw e;
    }
  }

  Future<void> _rotateSegment() async {
    if (!cameraController!.value.isRecordingVideo) {
      print('Não está gravando vídeo');
      return;
    }

    try {
      print('Rotacionando segmento');
      final xFile = await cameraController!.stopVideoRecording();
      videoSegments.add(xFile.path);
      print('Segmento salvo: ${xFile.path}');

      if (videoSegments.length > maxSegments) {
        final removed = videoSegments.removeAt(0);
        await VideoService.deleteFileIfExists(removed);
      }

      await _startNewSegment();
    } catch (e) {
      print('Erro ao rotacionar segmento: $e');
    }
  }

  Future<void> stopSegmentedRecording() async {
    _segmentTimer?.cancel();
    _segmentTimer = null;

    if (cameraController!.value.isRecordingVideo) {
      final xFile = await cameraController!.stopVideoRecording();
      videoSegments.add(xFile.path);

      if (videoSegments.length > maxSegments) {
        final removed = videoSegments.removeAt(0);
        await VideoService.deleteFileIfExists(removed);
      }
    }

    isRecording = false;
    _stopRecordingTimer();

    // Para o timer de volume e restaura o controle do usuário
    _volumeTimer?.cancel();
    _volumeTimer = null;

    notifyListeners();
  }

  Future<void> cutLast25Seconds() async {
    if (!isRecording || videoSegments.isEmpty) {
      print('Nenhum bloco gravado ainda!');
      return;
    }

    try {
      if (cameraController!.value.isRecordingVideo) {
        final xFile = await cameraController!.stopVideoRecording();
        videoSegments.add(xFile.path);
        print('Segmento atual adicionado: ${xFile.path}');

        if (videoSegments.length > maxSegments) {
          final removed = videoSegments.removeAt(0);
          await VideoService.deleteFileIfExists(removed);
        }

        if (isRecording) {
          await _startNewSegment();
        }
      }

      final concatenatedPath = await VideoService.createFinalVideo(
        videoSegments,
        _tempDir.path,
      );

      if (concatenatedPath == null) {
        print('Erro ao criar vídeo final');
        return;
      }

      final trimmedPath = await VideoService.trimVideoTo25Seconds(
        concatenatedPath,
        _tempDir.path,
      );

      if (trimmedPath == null) {
        print('Erro ao cortar vídeo');
        await VideoService.deleteFileIfExists(concatenatedPath);
        return;
      }

      final thumbnailPath = await VideoService.generateThumbnail(
        trimmedPath,
        _tempDir.path,
      );

      final recentVideo = RecentVideo(
        path: trimmedPath,
        timestamp: DateTime.now(),
        thumbnailPath: thumbnailPath,
      );

      recentVideos.insert(0, recentVideo);

      if (recentVideos.length > 10) {
        final oldVideo = recentVideos.removeLast();
        await VideoService.deleteFileIfExists(oldVideo.path);
        if (oldVideo.thumbnailPath != null) {
          await VideoService.deleteFileIfExists(oldVideo.thumbnailPath!);
        }
      }

      await _saveVideos();
      notifyListeners();

      await VideoService.deleteFileIfExists(concatenatedPath);
    } catch (e) {
      print('Erro ao cortar vídeo: $e');
    }
  }

  Future<void> switchCamera() async {
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

    if (isRecording) {
      await stopSegmentedRecording();
    }

    await cameraController?.dispose();
    _currentCamera = newCamera;
    await initializeCamera();
  }

  @override
  void dispose() {
    disposeVolumeControl();
    _segmentTimer?.cancel();
    _recordingTimer?.cancel();
    cameraController?.dispose();
    super.dispose();
  }
}
