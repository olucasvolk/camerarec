import 'dart:io';
import 'package:video_thumbnail/video_thumbnail.dart' as thumbnail;
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:flutter/services.dart';

class VideoService {
  static Future<Duration?> getVideoDuration(String path) async {
    try {
      final ctrl = VideoPlayerController.file(File(path));
      await ctrl.initialize();
      final d = ctrl.value.duration;
      await ctrl.dispose();
      return d;
    } catch (e) {
      print('Erro ao obter duração do vídeo: $e');
      return null;
    }
  }

  static Future<String?> generateThumbnail(
      String videoPath, String tempDir) async {
    try {
      final duration = await getVideoDuration(videoPath);
      if (duration == null) return null;

      // Pega o último frame do vídeo
      final thumbnailPath = await thumbnail.VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir,
        imageFormat: thumbnail.ImageFormat.JPEG,
        maxHeight: 512,
        quality: 85,
        timeMs: duration.inMilliseconds, // Usa o último momento do vídeo
      );

      return thumbnailPath;
    } catch (e) {
      print('Erro ao gerar thumbnail: $e');
      return null;
    }
  }

  static Future<String?> createFinalVideo(
    List<String> segments,
    String tempDir,
  ) async {
    try {
      if (segments.isEmpty) return null;

      final listFilePath =
          '$tempDir/segments_${DateTime.now().millisecondsSinceEpoch}.txt';
      final listFile = File(listFilePath);
      final sb = StringBuffer();

      for (var segPath in segments) {
        sb.writeln("file '${segPath.replaceAll("'", "'\\''")}'");
      }
      await listFile.writeAsString(sb.toString());

      final concatenatedPath =
          '$tempDir/concat_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Comando otimizado para alta qualidade
      final concatCmd =
          "-f concat -safe 0 -i '$listFilePath' -c:v copy -c:a copy -movflags +faststart '$concatenatedPath'";

      final concatSession = await FFmpegKit.execute(concatCmd);
      final concatReturnCode = await concatSession.getReturnCode();

      await deleteFileIfExists(listFilePath);

      if (!ReturnCode.isSuccess(concatReturnCode)) {
        print(
            'Erro ao concatenar vídeos: ${await concatSession.getLogsAsString()}');
        return null;
      }

      return concatenatedPath;
    } catch (e) {
      print('Erro ao criar vídeo final: $e');
      return null;
    }
  }

  static Future<String?> trimVideoTo25Seconds(
      String inputPath, String tempDir) async {
    try {
      final trimmedPath =
          '$tempDir/final25s_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final videoDuration = await getVideoDuration(inputPath);

      if (videoDuration == null) return null;

      String cmdCut;
      if (videoDuration.inSeconds > 25) {
        final startTime = videoDuration.inSeconds - 25;
        cmdCut =
            "-i '$inputPath' -ss $startTime -t 25 -c:v copy -c:a copy -movflags +faststart '$trimmedPath'";
      } else {
        cmdCut = "-i '$inputPath' -c copy -movflags +faststart '$trimmedPath'";
      }

      final session = await FFmpegKit.execute(cmdCut);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(trimmedPath);
        if (await outputFile.exists() && await outputFile.length() > 0) {
          final saved = await GallerySaver.saveVideo(trimmedPath);
          if (saved ?? false) {
            return trimmedPath;
          }
        }
      }

      print('Erro ao cortar vídeo: ${await session.getLogsAsString()}');
      return null;
    } catch (e) {
      print('Erro ao cortar vídeo: $e');
      return null;
    }
  }

  static Future<void> deleteFileIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Erro ao deletar arquivo: $e');
    }
  }
}
