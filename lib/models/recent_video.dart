import 'dart:convert';

class RecentVideo {
  final String path;
  final DateTime timestamp;
  String? thumbnailPath;

  RecentVideo({
    required this.path,
    required this.timestamp,
    this.thumbnailPath,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'timestamp': timestamp.toIso8601String(),
        'thumbnailPath': thumbnailPath,
      };

  factory RecentVideo.fromJson(Map<String, dynamic> json) => RecentVideo(
        path: json['path'],
        timestamp: DateTime.parse(json['timestamp']),
        thumbnailPath: json['thumbnailPath'],
      );
}
