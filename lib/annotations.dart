import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum AnnotationTool {
  none,
  highlighter,
  pen,
  eraser,
}

class DrawingPoint {
  final double x;
  final double y;

  const DrawingPoint(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory DrawingPoint.fromJson(Map<String, dynamic> json) => DrawingPoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      );
}

class DrawingStroke {
  final String id;
  final List<DrawingPoint> points;
  final Color color;
  final double strokeWidth;
  final bool isHighlighter;

  DrawingStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.isHighlighter,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((p) => p.toJson()).toList(),
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
        'isHighlighter': isHighlighter,
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) => DrawingStroke(
        id: json['id'] as String? ?? '${DateTime.now().microsecondsSinceEpoch}',
        points: (json['points'] as List<dynamic>? ?? [])
            .map((p) => DrawingPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        color: Color(json['color'] as int? ?? 0xFF2563EB),
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
        isHighlighter: json['isHighlighter'] as bool? ?? false,
      );
}

class AnnotationStorageService {
  static Future<Directory> _getAnnotationsDir() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final target = Directory('${dir.path}/Folio/annotations');
      if (!await target.exists()) {
        await target.create(recursive: true);
      }
      return target;
    } catch (_) {
      final appData = Platform.environment['APPDATA'] ??
          Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['HOME'];
      final baseDir = appData != null
          ? Directory('$appData/Folio/annotations')
          : Directory('${Directory.systemTemp.path}/Folio/annotations');
      if (!baseDir.existsSync()) {
        baseDir.createSync(recursive: true);
      }
      return baseDir;
    }
  }

  static String _getFileHash(String filePath) {
    int hash = 0;
    for (int i = 0; i < filePath.length; i++) {
      hash = (31 * hash + filePath.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash.toString();
  }

  static Future<Map<int, List<DrawingStroke>>> loadAnnotations(
      String filePath) async {
    try {
      final dir = await _getAnnotationsDir();
      final file = File('${dir.path}/${_getFileHash(filePath)}.json');
      if (!await file.exists()) {
        // Fallback check in %APPDATA%/Folio/annotations
        final appData = Platform.environment['APPDATA'];
        if (appData != null) {
          final oldFile = File('$appData/Folio/annotations/${_getFileHash(filePath)}.json');
          if (await oldFile.exists()) {
            final content = await oldFile.readAsString();
            if (content.trim().isNotEmpty) {
              await file.writeAsString(content);
            }
          }
        }
      }
      if (!await file.exists()) return {};

      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};

      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final Map<int, List<DrawingStroke>> result = {};

      decoded.forEach((key, val) {
        final pageNum = int.tryParse(key);
        if (pageNum != null && val is List) {
          result[pageNum] = val
              .map((s) => DrawingStroke.fromJson(s as Map<String, dynamic>))
              .toList();
        }
      });

      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveAnnotations(
      String filePath, Map<int, List<DrawingStroke>> annotations) async {
    try {
      final dir = await _getAnnotationsDir();
      final file = File('${dir.path}/${_getFileHash(filePath)}.json');

      final Map<String, dynamic> encoded = {};
      annotations.forEach((page, strokes) {
        if (strokes.isNotEmpty) {
          encoded[page.toString()] = strokes.map((s) => s.toJson()).toList();
        }
      });

      if (encoded.isEmpty) {
        if (await file.exists()) {
          await file.delete();
        }
      } else {
        await file.writeAsString(jsonEncode(encoded));
      }
    } catch (_) {}
  }
}

class AnnotationPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? activeStroke;
  final Size pageSize;

  AnnotationPainter({
    required this.strokes,
    this.activeStroke,
    required this.pageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / 595.0).clamp(0.5, 3.5);

    void drawSingleStroke(DrawingStroke stroke) {
      if (stroke.points.isEmpty) return;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = stroke.isHighlighter ? StrokeCap.round : StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (stroke.isHighlighter) {
        paint.color = stroke.color.withValues(alpha: 0.38);
        paint.blendMode = BlendMode.multiply;
        paint.strokeWidth = stroke.strokeWidth * scale;
      } else {
        paint.color = stroke.color;
        paint.blendMode = BlendMode.srcOver;
        paint.strokeWidth = stroke.strokeWidth * scale;
      }

      if (stroke.points.length == 1) {
        final pt = Offset(
          stroke.points[0].x * size.width,
          stroke.points[0].y * size.height,
        );
        final dotPaint = Paint()
          ..color = stroke.isHighlighter
              ? stroke.color.withValues(alpha: 0.38)
              : stroke.color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, paint.strokeWidth / 2, dotPaint);
        return;
      }

      final path = Path();
      for (int i = 0; i < stroke.points.length; i++) {
        final pt = Offset(
          stroke.points[i].x * size.width,
          stroke.points[i].y * size.height,
        );
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }

      canvas.drawPath(path, paint);
    }

    for (final stroke in strokes) {
      drawSingleStroke(stroke);
    }

    if (activeStroke != null) {
      drawSingleStroke(activeStroke!);
    }
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) {
    return true;
  }
}

class PdfPageAnnotationOverlay extends StatefulWidget {
  final int pageNumber;
  final Size pageSize;
  final List<DrawingStroke> strokes;
  final AnnotationTool activeTool;
  final Color selectedColor;
  final double strokeWidth;
  final ValueChanged<DrawingStroke> onStrokeAdded;
  final ValueChanged<Offset> onErase;

  const PdfPageAnnotationOverlay({
    super.key,
    required this.pageNumber,
    required this.pageSize,
    required this.strokes,
    required this.activeTool,
    required this.selectedColor,
    required this.strokeWidth,
    required this.onStrokeAdded,
    required this.onErase,
  });

  @override
  State<PdfPageAnnotationOverlay> createState() =>
      _PdfPageAnnotationOverlayState();
}

class _PdfPageAnnotationOverlayState extends State<PdfPageAnnotationOverlay> {
  List<DrawingPoint>? _currentPoints;

  void _onPointerDown(PointerDownEvent event) {
    if (widget.activeTool == AnnotationTool.none) return;

    final localPos = event.localPosition;
    if (widget.activeTool == AnnotationTool.eraser) {
      widget.onErase(localPos);
      return;
    }

    final normalizedX = (localPos.dx / widget.pageSize.width).clamp(0.0, 1.0);
    final normalizedY = (localPos.dy / widget.pageSize.height).clamp(0.0, 1.0);

    setState(() {
      _currentPoints = [DrawingPoint(normalizedX, normalizedY)];
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (widget.activeTool == AnnotationTool.none) return;

    final localPos = event.localPosition;
    if (widget.activeTool == AnnotationTool.eraser) {
      widget.onErase(localPos);
      return;
    }

    if (_currentPoints == null) return;

    final normalizedX = (localPos.dx / widget.pageSize.width).clamp(0.0, 1.0);
    final normalizedY = (localPos.dy / widget.pageSize.height).clamp(0.0, 1.0);

    final lastPt = _currentPoints!.last;
    final dx = (normalizedX - lastPt.x) * widget.pageSize.width;
    final dy = (normalizedY - lastPt.y) * widget.pageSize.height;
    if (math.sqrt(dx * dx + dy * dy) > 1.5) {
      setState(() {
        _currentPoints!.add(DrawingPoint(normalizedX, normalizedY));
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_currentPoints != null && _currentPoints!.isNotEmpty) {
      final stroke = DrawingStroke(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        points: List.from(_currentPoints!),
        color: widget.selectedColor,
        strokeWidth: widget.strokeWidth,
        isHighlighter: widget.activeTool == AnnotationTool.highlighter,
      );
      widget.onStrokeAdded(stroke);
    }
    setState(() {
      _currentPoints = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeStroke = _currentPoints != null && _currentPoints!.isNotEmpty
        ? DrawingStroke(
            id: 'active',
            points: _currentPoints!,
            color: widget.selectedColor,
            strokeWidth: widget.strokeWidth,
            isHighlighter: widget.activeTool == AnnotationTool.highlighter,
          )
        : null;

    final customPaint = CustomPaint(
      size: widget.pageSize,
      painter: AnnotationPainter(
        strokes: widget.strokes,
        activeStroke: activeStroke,
        pageSize: widget.pageSize,
      ),
    );

    if (widget.activeTool == AnnotationTool.none) {
      return IgnorePointer(child: customPaint);
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: customPaint,
    );
  }
}
