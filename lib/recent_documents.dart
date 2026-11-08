import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RecentDocument {
  final String filePath;
  final String fileName;
  final DateTime lastOpened;
  final int fileSize;

  RecentDocument({
    required this.filePath,
    required this.fileName,
    required this.lastOpened,
    required this.fileSize,
  });

  bool get exists => File(filePath).existsSync();

  String get formattedSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(lastOpened);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays == 1) return 'Dün';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${lastOpened.day.toString().padLeft(2, '0')}.${lastOpened.month.toString().padLeft(2, '0')}.${lastOpened.year}';
  }

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileName': fileName,
        'lastOpened': lastOpened.toIso8601String(),
        'fileSize': fileSize,
      };

  factory RecentDocument.fromJson(Map<String, dynamic> json) => RecentDocument(
        filePath: json['filePath'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        lastOpened: DateTime.tryParse(json['lastOpened'] as String? ?? '') ??
            DateTime.now(),
        fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      );
}

class RecentDocumentsService {
  static const int _maxRecents = 25;

  static Future<Directory> _getBaseDir() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final folioDir = Directory('${dir.path}/Folio');
      if (!await folioDir.exists()) {
        await folioDir.create(recursive: true);
      }
      return folioDir;
    } catch (_) {
      final appData = Platform.environment['APPDATA'] ??
          Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['HOME'];
      final baseDir = appData != null
          ? Directory('$appData/Folio')
          : Directory('${Directory.systemTemp.path}/Folio');
      if (!baseDir.existsSync()) {
        baseDir.createSync(recursive: true);
      }
      return baseDir;
    }
  }

  static Future<File> _getFile() async {
    final baseDir = await _getBaseDir();
    return File('${baseDir.path}/recent_documents.json');
  }

  static Future<List<RecentDocument>> getRecentDocuments() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        // Fallback check in %APPDATA%/Folio on Windows if exists
        final appData = Platform.environment['APPDATA'];
        if (appData != null) {
          final oldFile = File('$appData/Folio/recent_documents.json');
          if (await oldFile.exists()) {
            final content = await oldFile.readAsString();
            if (content.trim().isNotEmpty) {
              await file.writeAsString(content);
            }
          }
        }
      }
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((item) => RecentDocument.fromJson(item as Map<String, dynamic>))
          .where((doc) => doc.filePath.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addDocument(String filePath) async {
    try {
      if (filePath.trim().isEmpty) return;
      final f = File(filePath);
      int size = 0;
      if (await f.exists()) {
        try {
          size = await f.length();
        } catch (_) {}
      }

      final separator = filePath.contains(r'\') ? r'\' : '/';
      final fileName = filePath.split(separator).last;
      final docs = await getRecentDocuments();

      docs.removeWhere((d) => d.filePath.toLowerCase() == filePath.toLowerCase());

      docs.insert(
        0,
        RecentDocument(
          filePath: filePath,
          fileName: fileName,
          lastOpened: DateTime.now(),
          fileSize: size,
        ),
      );

      if (docs.length > _maxRecents) {
        docs.removeRange(_maxRecents, docs.length);
      }

      final file = await _getFile();
      await file.writeAsString(jsonEncode(docs.map((d) => d.toJson()).toList()));
    } catch (_) {}
  }

  static Future<void> removeDocument(String filePath) async {
    try {
      final docs = await getRecentDocuments();
      docs.removeWhere((d) => d.filePath.toLowerCase() == filePath.toLowerCase());
      final file = await _getFile();
      await file.writeAsString(jsonEncode(docs.map((d) => d.toJson()).toList()));
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
