import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'annotations.dart';
import 'recent_documents.dart';
import 'recent_documents_view.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();

  final List<String> initialFiles = [];
  for (final arg in args) {
    final candidate = arg.replaceAll('"', '').trim();
    if (candidate.isNotEmpty && File(candidate).existsSync()) {
      initialFiles.add(candidate);
    }
  }

  runApp(PdfReaderApp(
    initialFilePath: initialFiles.isNotEmpty ? initialFiles.first : null,
    initialFilePaths: initialFiles,
  ));
}

class PdfReaderApp extends StatefulWidget {
  final String? initialFilePath;
  final List<String>? initialFilePaths;

  const PdfReaderApp({
    super.key,
    this.initialFilePath,
    this.initialFilePaths,
  });

  @override
  State<PdfReaderApp> createState() => _PdfReaderAppState();
}

class _PdfReaderAppState extends State<PdfReaderApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      final systemDark =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark;
      if (_themeMode == ThemeMode.system) {
        _themeMode = systemDark ? ThemeMode.light : ThemeMode.dark;
      } else if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Folio - Modern PDF Reader',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E2024),
        ),
        scaffoldBackgroundColor: const Color(0xFF121417),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181A1F),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: PdfViewerHomeScreen(
        initialFilePath: widget.initialFilePath,
        initialFilePaths: widget.initialFilePaths,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class PdfTab {
  final String id;
  String filePath;
  String fileName;
  final PdfViewerController controller;
  PdfTextSearcher? textSearcher;
  PdfDocument? document;
  int currentPage;
  int totalPages;
  double zoomRatio;
  Map<int, List<DrawingStroke>> annotations;
  List<Map<String, dynamic>> undoHistory;

  PdfTab({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.controller,
    this.textSearcher,
    this.document,
    this.currentPage = 1,
    this.totalPages = 0,
    this.zoomRatio = 1.0,
    Map<int, List<DrawingStroke>>? annotations,
    List<Map<String, dynamic>>? undoHistory,
  })  : annotations = annotations ?? {},
        undoHistory = undoHistory ?? [];
}

class PdfViewerHomeScreen extends StatefulWidget {
  final String? initialFilePath;
  final List<String>? initialFilePaths;
  final VoidCallback onToggleTheme;

  const PdfViewerHomeScreen({
    super.key,
    this.initialFilePath,
    this.initialFilePaths,
    required this.onToggleTheme,
  });

  @override
  State<PdfViewerHomeScreen> createState() => _PdfViewerHomeScreenState();
}

class _PdfViewerHomeScreenState extends State<PdfViewerHomeScreen> {
  final List<PdfTab> _tabs = [];
  int _activeTabIndex = -1;

  PdfTab? get _activeTab =>
      (_tabs.isNotEmpty && _activeTabIndex >= 0 && _activeTabIndex < _tabs.length)
          ? _tabs[_activeTabIndex]
          : null;

  PdfViewerController? get _pdfController => _activeTab?.controller;
  PdfDocument? get _document => _activeTab?.document;
  int get _currentPage => _activeTab?.currentPage ?? 1;
  int get _totalPages => _activeTab?.totalPages ?? 0;
  double get _zoomRatio => _activeTab?.zoomRatio ?? 1.0;

  late bool _isSidebarVisible;
  bool _isLoading = false;
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final ScrollController _thumbnailScrollController = ScrollController();
  static const MethodChannel _openFileChannel = MethodChannel('folio/open_file');

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  String get _modKey => Platform.isMacOS ? '⌘' : 'Ctrl';

  List<RecentDocument> _recentDocuments = [];
  AnnotationTool _activeAnnotationTool = AnnotationTool.none;
  Color _selectedPenColor = const Color(0xFF2563EB);
  Color _selectedHighlighterColor = const Color(0xFFFACC15);
  double _penWidth = 3.0;
  double _highlighterWidth = 24.0;

  @override
  void initState() {
    super.initState();
    _isSidebarVisible = !_isMobile;

    _initOpenFileChannel();
    _loadRecentDocuments();

    if (widget.initialFilePaths != null && widget.initialFilePaths!.isNotEmpty) {
      for (final p in widget.initialFilePaths!) {
        _checkAndOpenFile(p);
      }
    } else if (widget.initialFilePath != null) {
      _checkAndOpenFile(widget.initialFilePath!);
    }
  }

  Future<void> _loadRecentDocuments() async {
    final docs = await RecentDocumentsService.getRecentDocuments();
    if (mounted) {
      setState(() {
        _recentDocuments = docs;
      });
    }
  }

  void _logDebug(String msg) {
    try {
      final logDir = Directory.systemTemp.path;
      final f = File('$logDir/folio_debug.log');
      f.writeAsStringSync('${DateTime.now()} [Dart]: $msg\n', mode: FileMode.append);
    } catch (_) {}
  }

  void _initOpenFileChannel() {
    _logDebug('_initOpenFileChannel registered');
    _openFileChannel.setMethodCallHandler((call) async {
      _logDebug('_openFileChannel method: ${call.method}, args: ${call.arguments}');
      if (call.method == 'onOpenFiles') {
        final args = call.arguments;
        if (args is List) {
          for (final item in args) {
            if (item != null && item.toString().trim().isNotEmpty) {
              _checkAndOpenFile(item.toString());
            }
          }
        } else if (args != null && args.toString().trim().isNotEmpty) {
          _checkAndOpenFile(args.toString());
        }
      }
    });

    _checkInitialFilesFromChannel();
  }

  Future<void> _checkInitialFilesFromChannel() async {
    try {
      _logDebug('Calling getInitialFiles...');
      final result = await _openFileChannel.invokeMethod<dynamic>('getInitialFiles');
      _logDebug('getInitialFiles returned: $result');
      if (result is List && result.isNotEmpty) {
        for (final item in result) {
          if (item != null && item.toString().trim().isNotEmpty) {
            _checkAndOpenFile(item.toString());
          }
        }
      }
    } catch (e) {
      _logDebug('Initial files error: $e');
      debugPrint('Initial files error: $e');
    }
  }

  @override
  void dispose() {
    for (final tab in _tabs) {
      tab.textSearcher?.dispose();
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  void _onTabControllerUpdate(PdfTab tab) {
    if (!mounted) return;

    final newZoom = tab.controller.currentZoom;
    final newPage = tab.controller.pageNumber;
    bool needsState = false;

    if ((newZoom - tab.zoomRatio).abs() > 0.005) {
      tab.zoomRatio = newZoom;
      needsState = true;
    }

    if (newPage != null && newPage != tab.currentPage) {
      tab.currentPage = newPage;
      needsState = true;
      if (tab == _activeTab) {
        _scrollToThumbnail(newPage);
      }
    }

    if (needsState && tab == _activeTab) {
      setState(() {});
    }
  }

  void _scrollToThumbnail(int page) {
    if (!_thumbnailScrollController.hasClients || !_isSidebarVisible) return;
    const itemHeight = 180.0;
    final targetOffset = (page - 1) * itemHeight;
    _thumbnailScrollController.animateTo(
      targetOffset.clamp(
        0.0,
        _thumbnailScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickAndOpenFile() async {
    try {
      setState(() => _isLoading = true);
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        dialogTitle: 'Bir veya Birden Fazla PDF Dosyası Seçin',
      );

      if (files.isNotEmpty) {
        for (final file in files) {
          if (file.path != null) {
            _checkAndOpenFile(file.path!);
          }
        }
      }
    } catch (e, stack) {
      _logDebug('Error in _pickAndOpenFile: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya seçilirken bir hata oluştu: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _checkAndOpenFile(String rawPath) {
    var path = rawPath.trim();
    if (path.startsWith('file://')) {
      final uri = Uri.tryParse(path);
      if (uri != null) {
        try {
          path = uri.toFilePath();
        } catch (_) {
          path = uri.path;
        }
      }
    }
    if (path.isEmpty) return;
    _logDebug('_checkAndOpenFile called for: $path');

    try {
      final f = File(path);
      if (f.existsSync() && f.lengthSync() > 5) {
        final header = String.fromCharCodes(f.openSync().readSync(5));
        if (!header.startsWith('%PDF-')) {
          _showInvalidFormatDialog(path);
          return;
        }
      }
    } catch (_) {}
    _openFile(path);
  }

  void _showInvalidFormatDialog(String path) {
    final fileName = _getFileName(path);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text('Geçersiz PDF Formatı'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$fileName" dosyası .pdf uzantısına sahip ancak standart bir PDF dosyası değil.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Bu dosya muhtemelen bir web sitesi (örn. banka dekontu veya e-devlet) tarafından PDF olarak adlandırılmış bir HTML web sayfasıdır.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _pickAndOpenFile();
            },
            icon: const Icon(Icons.file_open_rounded, size: 18),
            label: const Text('Farklı Dosya Seç'),
          ),
        ],
      ),
    );
  }

  void _openFile(String path) {
    final existingIndex = _tabs.indexWhere((t) => t.filePath == path);
    if (existingIndex != -1) {
      setState(() {
        _activeTabIndex = existingIndex;
      });
      return;
    }

    final controller = PdfViewerController();
    final tab = PdfTab(
      id: '${DateTime.now().microsecondsSinceEpoch}_${path.hashCode}',
      filePath: path,
      fileName: _getFileName(path),
      controller: controller,
    );

    controller.addListener(() => _onTabControllerUpdate(tab));

    setState(() {
      _tabs.add(tab);
      _activeTabIndex = _tabs.length - 1;
    });

    RecentDocumentsService.addDocument(path).then((_) {
      if (mounted) _loadRecentDocuments();
    });

    AnnotationStorageService.loadAnnotations(path).then((saved) {
      if (saved.isNotEmpty && mounted) {
        setState(() {
          tab.annotations = saved;
        });
      }
    });
  }

  void _closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    final tab = _tabs[index];
    tab.textSearcher?.dispose();

    setState(() {
      _tabs.removeAt(index);
      if (_tabs.isEmpty) {
        _activeTabIndex = -1;
        _activeAnnotationTool = AnnotationTool.none;
      } else if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      } else if (_activeTabIndex > index) {
        _activeTabIndex--;
      }
    });

    if (_tabs.isEmpty) {
      _loadRecentDocuments();
    }
  }

  void _onStrokeAdded(PdfTab tab, int pageNumber, DrawingStroke stroke) {
    setState(() {
      tab.annotations.putIfAbsent(pageNumber, () => []).add(stroke);
      tab.undoHistory.add({
        'type': 'add',
        'page': pageNumber,
        'stroke': stroke,
      });
    });
    AnnotationStorageService.saveAnnotations(tab.filePath, tab.annotations);
  }

  void _onEraseAtPoint(
      PdfTab tab, int pageNumber, Offset localPoint, Size pageSize) {
    final strokes = tab.annotations[pageNumber];
    if (strokes == null || strokes.isEmpty) return;

    final toRemove = <DrawingStroke>[];
    for (final stroke in strokes) {
      for (final pt in stroke.points) {
        final screenX = pt.x * pageSize.width;
        final screenY = pt.y * pageSize.height;
        final dist = math.sqrt(math.pow(screenX - localPoint.dx, 2) +
            math.pow(screenY - localPoint.dy, 2));
        if (dist < 20.0) {
          toRemove.add(stroke);
          break;
        }
      }
    }

    if (toRemove.isNotEmpty) {
      setState(() {
        for (final s in toRemove) {
          strokes.remove(s);
          tab.undoHistory.add({
            'type': 'remove',
            'page': pageNumber,
            'stroke': s,
          });
        }
      });
      AnnotationStorageService.saveAnnotations(tab.filePath, tab.annotations);
    }
  }

  void _undoAnnotation(PdfTab tab) {
    if (tab.undoHistory.isEmpty) return;
    final lastAction = tab.undoHistory.removeLast();
    final page = lastAction['page'] as int;
    final stroke = lastAction['stroke'] as DrawingStroke;
    final type = lastAction['type'] as String;

    setState(() {
      if (type == 'add') {
        tab.annotations[page]?.removeWhere((s) => s.id == stroke.id);
      } else if (type == 'remove') {
        tab.annotations.putIfAbsent(page, () => []).add(stroke);
      }
    });
    AnnotationStorageService.saveAnnotations(tab.filePath, tab.annotations);
  }

  void _clearPageAnnotations(PdfTab tab, int pageNumber) {
    final pageStrokes = tab.annotations[pageNumber];
    if (pageStrokes == null || pageStrokes.isEmpty) return;

    setState(() {
      for (final s in pageStrokes) {
        tab.undoHistory.add({
          'type': 'remove',
          'page': pageNumber,
          'stroke': s,
        });
      }
      tab.annotations.remove(pageNumber);
    });
    AnnotationStorageService.saveAnnotations(tab.filePath, tab.annotations);
  }

  void _confirmClearPageAnnotations(PdfTab tab, int pageNumber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Çizimleri Temizle'),
          ],
        ),
        content: Text(
          'Sayfa $pageNumber üzerindeki tüm kalem ve vurgulayıcı çizimlerini silmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _clearPageAnnotations(tab, pageNumber);
            },
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }

  void _closeDocument() {
    if (_activeTabIndex >= 0 && _activeTabIndex < _tabs.length) {
      _closeTab(_activeTabIndex);
    }
  }

  void _nextTab() {
    if (_tabs.length > 1) {
      setState(() {
        _activeTabIndex = (_activeTabIndex + 1) % _tabs.length;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeTab != null) {
          _scrollToThumbnail(_activeTab!.currentPage);
        }
      });
    }
  }

  void _prevTab() {
    if (_tabs.length > 1) {
      setState(() {
        _activeTabIndex = (_activeTabIndex - 1 + _tabs.length) % _tabs.length;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeTab != null) {
          _scrollToThumbnail(_activeTab!.currentPage);
        }
      });
    }
  }

  static const List<double> _zoomLevels = [
    0.25, 0.35, 0.50, 0.65, 0.75, 0.85, 1.00, 1.15, 1.25, 1.50, 1.75, 2.00, 2.50, 3.00, 4.00, 5.00
  ];

  void _zoomIn() {
    final controller = _pdfController;
    if (controller == null || !controller.isReady) return;
    final current = controller.currentZoom;
    double next = current * 1.2;
    for (final level in _zoomLevels) {
      if (level > current + 0.04) {
        next = level;
        break;
      }
    }
    next = next.clamp(0.2, 5.0);
    final center = controller.viewSize.center(Offset.zero);
    controller.setZoom(center, next);
  }

  void _zoomOut() {
    final controller = _pdfController;
    if (controller == null || !controller.isReady) return;
    final current = controller.currentZoom;
    double prev = current / 1.2;
    for (int i = _zoomLevels.length - 1; i >= 0; i--) {
      if (_zoomLevels[i] < current - 0.04) {
        prev = _zoomLevels[i];
        break;
      }
    }
    prev = prev.clamp(0.2, 5.0);
    final center = controller.viewSize.center(Offset.zero);
    controller.setZoom(center, prev);
  }

  void _fitWidth() {
    final controller = _pdfController;
    if (controller == null || !controller.isReady) return;
    final matrix = controller.calcMatrixFitWidthForPage(pageNumber: _currentPage);
    if (matrix != null) {
      controller.value = matrix;
      if (_activeTab != null) {
        setState(() {
          _activeTab!.zoomRatio = controller.currentZoom;
        });
      }
    }
  }

  void _fitPage() {
    final controller = _pdfController;
    if (controller == null || !controller.isReady) return;
    final matrix = controller.calcMatrixForFit(pageNumber: _currentPage);
    if (matrix != null) {
      controller.value = matrix;
      if (_activeTab != null) {
        setState(() {
          _activeTab!.zoomRatio = controller.currentZoom;
        });
      }
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (_isSearchVisible) {
        _searchFocusNode.requestFocus();
        final query = _searchController.text.trim();
        if (query.isNotEmpty) {
          _activeTab?.textSearcher?.startTextSearch(query);
        }
      } else {
        _activeTab?.textSearcher?.resetTextSearch();
      }
    });
  }

  void _closeSearch() {
    if (!_isSearchVisible) return;
    setState(() {
      _isSearchVisible = false;
      _activeTab?.textSearcher?.resetTextSearch();
    });
  }

  void _onSearchChanged(String query) {
    final searcher = _activeTab?.textSearcher;
    if (searcher == null) return;
    final q = query.trim();
    if (q.isEmpty) {
      searcher.resetTextSearch();
    } else {
      searcher.startTextSearch(q);
    }
  }

  void _searchNext() {
    _activeTab?.textSearcher?.goToNextMatch();
  }

  void _searchPrev() {
    _activeTab?.textSearcher?.goToPrevMatch();
  }

  void _resetZoom() {
    _fitWidth();
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      _pdfController?.goToPage(pageNumber: _currentPage - 1);
    }
  }

  void _goToNextPage() {
    if (_currentPage < _totalPages) {
      _pdfController?.goToPage(pageNumber: _currentPage + 1);
    }
  }

  Future<void> _showPageJumpDialog() async {
    if (_totalPages <= 1) return;
    final textController = TextEditingController(text: '$_currentPage');

    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sayfaya Git'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Sayfa Numarası (1 - $_totalPages)',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final page = int.tryParse(value);
            Navigator.pop(ctx, page);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(textController.text);
              Navigator.pop(ctx, page);
            },
            child: const Text('Git'),
          ),
        ],
      ),
    );

    if (target != null && target >= 1 && target <= _totalPages) {
      _pdfController?.goToPage(pageNumber: target);
    }
  }

  String _getFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _shareActiveDocument() async {
    final activeTab = _activeTab;
    if (activeTab == null) return;
    try {
      final file = File(activeTab.filePath);
      if (!file.existsSync()) {
        _showSnackBar('Paylaşılacak dosya bulunamadı: ${activeTab.filePath}', isError: true);
        return;
      }

      await _openFileChannel.invokeMethod('shareFile', {
        'path': activeTab.filePath,
        'title': activeTab.fileName,
      });
    } catch (e) {
      _showSnackBar('Paylaşım başlatılamadı: $e', isError: true);
    }
  }

  Future<void> _saveActiveDocumentAs() async {
    final activeTab = _activeTab;
    if (activeTab == null) return;
    try {
      final file = File(activeTab.filePath);
      if (!file.existsSync()) {
        _showSnackBar('Kaynak dosya bulunamadı: ${activeTab.filePath}', isError: true);
        return;
      }

      final bytes = await file.readAsBytes();
      final uri = await FilePicker.saveFile(
        fileName: activeTab.fileName,
        bytes: bytes,
        mimeType: 'application/pdf',
        dialogTitle: 'PDF Dosyasını Kaydet',
      );

      if (uri != null) {
        _showSnackBar('Dosya başarıyla kaydedildi: ${activeTab.fileName}');
      }
    } catch (e) {
      _showSnackBar('Dosya kaydedilemedi: $e', isError: true);
    }
  }

  Future<void> _moveActiveDocument() async {
    final activeTab = _activeTab;
    if (activeTab == null) return;
    try {
      final file = File(activeTab.filePath);
      if (!file.existsSync()) {
        _showSnackBar('Kaynak dosya bulunamadı: ${activeTab.filePath}', isError: true);
        return;
      }

      final targetDir = await FilePicker.getDirectoryPath(
        dialogTitle: 'Taşınacak Hedef Klasörü Seçin',
      );
      if (targetDir == null || targetDir.isEmpty) return;

      final targetFile = File('$targetDir${Platform.pathSeparator}${activeTab.fileName}');
      if (targetFile.path == file.path) {
        _showSnackBar('Dosya zaten bu klasörde bulunuyor.');
        return;
      }

      final bytes = await file.readAsBytes();
      await targetFile.writeAsBytes(bytes);

      try {
        await file.delete();
      } catch (_) {}

      setState(() {
        activeTab.filePath = targetFile.path;
      });

      _showSnackBar('Dosya başarıyla taşındı:\n${targetFile.path}');
    } catch (e) {
      _showSnackBar('Dosya taşınamadı: $e', isError: true);
    }
  }

  Future<void> _renameActiveDocument() async {
    final activeTab = _activeTab;
    if (activeTab == null) return;

    final file = File(activeTab.filePath);
    if (!file.existsSync()) {
      _showSnackBar('Kaynak dosya bulunamadı', isError: true);
      return;
    }

    final currentBaseName = activeTab.fileName.toLowerCase().endsWith('.pdf')
        ? activeTab.fileName.substring(0, activeTab.fileName.length - 4)
        : activeTab.fileName;

    final textController = TextEditingController(text: currentBaseName);

    final newBaseName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, size: 20),
            SizedBox(width: 8),
            Text('Yeniden Adlandır'),
          ],
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Yeni Dosya Adı',
            suffixText: '.pdf',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) => Navigator.pop(ctx, val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (newBaseName == null || newBaseName.isEmpty || newBaseName == currentBaseName) {
      return;
    }

    final sanitized = newBaseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final newFileName = '$sanitized.pdf';
    final newPath = '${file.parent.path}${Platform.pathSeparator}$newFileName';

    try {
      final renamedFile = await file.rename(newPath);
      setState(() {
        activeTab.fileName = newFileName;
        activeTab.filePath = renamedFile.path;
      });
      _showSnackBar('Dosya yeniden adlandırıldı: $newFileName');
    } catch (_) {
      try {
        final newFile = File(newPath);
        await newFile.writeAsBytes(await file.readAsBytes());
        await file.delete();
        setState(() {
          activeTab.fileName = newFileName;
          activeTab.filePath = newFile.path;
        });
        _showSnackBar('Dosya yeniden adlandırıldı: $newFileName');
      } catch (err) {
        _showSnackBar('Yeniden adlandırılamadı: $err', isError: true);
      }
    }
  }

  Future<void> _showDocumentInfo() async {
    final activeTab = _activeTab;
    if (activeTab == null) return;

    int fileSize = 0;
    DateTime? lastModified;
    try {
      final f = File(activeTab.filePath);
      if (f.existsSync()) {
        fileSize = f.lengthSync();
        lastModified = f.lastModifiedSync();
      }
    } catch (_) {}

    String formatBytes(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    String formatDate(DateTime dt) {
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('Belge Bilgileri'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Dosya Adı', activeTab.fileName, isDark),
            const SizedBox(height: 10),
            _buildInfoRow('Sayfa Sayısı', '${_totalPages > 0 ? _totalPages : activeTab.totalPages} sayfa', isDark),
            const SizedBox(height: 10),
            if (fileSize > 0) ...[
              _buildInfoRow('Dosya Boyutu', formatBytes(fileSize), isDark),
              const SizedBox(height: 10),
            ],
            if (lastModified != null) ...[
              _buildInfoRow('Son Düzenleme', formatDate(lastModified), isDark),
              const SizedBox(height: 10),
            ],
            _buildInfoRow('Konum', activeTab.filePath, isDark, isPath: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {bool isPath = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isPath ? 11 : 13,
            fontWeight: isPath ? FontWeight.normal : FontWeight.w600,
            color: isPath && isDark ? Colors.grey.shade300 : null,
          ),
          maxLines: isPath ? 3 : 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showThumbnailsBottomSheet(BuildContext context) {
    if (_document == null || _totalPages == 0) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF181A1F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Sayfalar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF262930)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_currentPage / $_totalPages',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? const Color(0xFF2C2F36)
                      : const Color(0xFFE5E7EB),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _totalPages,
                    itemBuilder: (context, index) {
                      final pageNumber = index + 1;
                      final isSelected = pageNumber == _currentPage;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _pdfController?.goToPage(pageNumber: pageNumber);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : (isDark
                                      ? const Color(0xFF2E323B)
                                      : const Color(0xFFE2E8F0)),
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                  child: Container(
                                    color: Colors.white,
                                    width: double.infinity,
                                    child: PdfPageView(
                                      document: _document,
                                      pageNumber: pageNumber,
                                      maximumDpi: 80,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  '$pageNumber',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMobileAnnotationBottomSheet(
      BuildContext context, PdfTab? activeTab) {
    if (activeTab == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final highlighterColors = [
      const Color(0xFFFACC15),
      const Color(0xFF4ADE80),
      const Color(0xFF60A5FA),
      const Color(0xFFF472B6),
      const Color(0xFFFB923C),
    ];

    final penColors = [
      const Color(0xFF2563EB),
      const Color(0xFFDC2626),
      const Color(0xFF1E293B),
      const Color(0xFF16A34A),
      const Color(0xFF9333EA),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF181A1F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isHighlighter =
                _activeAnnotationTool == AnnotationTool.highlighter;
            final isPen = _activeAnnotationTool == AnnotationTool.pen;
            final isEraser = _activeAnnotationTool == AnnotationTool.eraser;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded,
                            size: 22, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 8),
                        const Text(
                          'Vurgulayıcı & Kalem Araçları',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (activeTab.undoHistory.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.undo_rounded),
                            tooltip: 'Geri Al',
                            onPressed: () {
                              _undoAnnotation(activeTab);
                              setModalState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Gezinme')),
                            selected:
                                _activeAnnotationTool == AnnotationTool.none,
                            avatar: const Icon(Icons.near_me_rounded, size: 16),
                            onSelected: (_) {
                              setState(() =>
                                  _activeAnnotationTool = AnnotationTool.none);
                              setModalState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Vurgula')),
                            selected: isHighlighter,
                            avatar:
                                const Icon(Icons.border_color_rounded, size: 16),
                            onSelected: (_) {
                              setState(() => _activeAnnotationTool =
                                  AnnotationTool.highlighter);
                              setModalState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Kalem')),
                            selected: isPen,
                            avatar: const Icon(Icons.edit_rounded, size: 16),
                            onSelected: (_) {
                              setState(() =>
                                  _activeAnnotationTool = AnnotationTool.pen);
                              setModalState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Silgi')),
                            selected: isEraser,
                            avatar: const Icon(Icons.auto_fix_normal_rounded,
                                size: 16),
                            onSelected: (_) {
                              setState(() => _activeAnnotationTool =
                                  AnnotationTool.eraser);
                              setModalState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    if (isHighlighter || isPen) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'Renk Seçin:',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: (isHighlighter ? highlighterColors : penColors)
                            .map((color) {
                          final isSelected = isHighlighter
                              ? _selectedHighlighterColor.toARGB32() ==
                                  color.toARGB32()
                              : _selectedPenColor.toARGB32() == color.toARGB32();
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isHighlighter) {
                                  _selectedHighlighterColor = color;
                                } else {
                                  _selectedPenColor = color;
                                }
                              });
                              setModalState(() {});
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black)
                                      : (isDark
                                          ? Colors.white24
                                          : Colors.black12),
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (activeTab.annotations.containsKey(_currentPage) &&
                            (activeTab.annotations[_currentPage]?.isNotEmpty ??
                                false))
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _confirmClearPageAnnotations(
                                  activeTab, _currentPage);
                            },
                            icon: const Icon(Icons.delete_sweep_rounded,
                                color: Colors.redAccent, size: 18),
                            label: const Text('Bu Sayfayı Temizle',
                                style: TextStyle(color: Colors.redAccent)),
                          ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Tamam'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? const Color(0xFF1E2024) : const Color(0xFFFFFFFF);
    final borderColor =
        isDark ? const Color(0xFF2C2F36) : const Color(0xFFE5E7EB);

    return CallbackShortcuts(
      bindings: {
        // Ctrl shortcuts (Windows, Linux, Android)
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _pickAndOpenFile,
        const SingleActivator(LogicalKeyboardKey.equal, control: true):
            _zoomIn,
        const SingleActivator(LogicalKeyboardKey.minus, control: true):
            _zoomOut,
        const SingleActivator(LogicalKeyboardKey.digit0, control: true):
            _resetZoom,
        const SingleActivator(LogicalKeyboardKey.keyW, control: true):
            _closeDocument,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.tab, control: true):
            _nextTab,
        const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
            _prevTab,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
          if (!_isMobile) {
            setState(() => _isSidebarVisible = !_isSidebarVisible);
          }
        },
        // Cmd shortcuts (macOS)
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true):
            _pickAndOpenFile,
        const SingleActivator(LogicalKeyboardKey.equal, meta: true):
            _zoomIn,
        const SingleActivator(LogicalKeyboardKey.minus, meta: true):
            _zoomOut,
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
            _resetZoom,
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true):
            _closeDocument,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.tab, meta: true):
            _nextTab,
        const SingleActivator(LogicalKeyboardKey.tab, meta: true, shift: true):
            _prevTab,
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () {
          if (!_isMobile) {
            setState(() => _isSidebarVisible = !_isSidebarVisible);
          }
        },
        // Navigation shortcuts
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _goToPreviousPage,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _goToNextPage,
        const SingleActivator(LogicalKeyboardKey.escape): _closeSearch,
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: _tabs.isEmpty && _activeAnnotationTool == AnnotationTool.none,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_activeAnnotationTool != AnnotationTool.none) {
              setState(() => _activeAnnotationTool = AnnotationTool.none);
              return;
            }
            if (_tabs.isNotEmpty) {
              _closeDocument();
            }
          },
          child: Scaffold(
            appBar: _buildAppBar(context, isDark, surfaceColor, borderColor),
            body: _tabs.isEmpty
                ? _buildEmptyView(isDark)
                : _buildPdfView(isDark),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark,
      Color surfaceColor, Color borderColor) {
    final isCompact = _isMobile || MediaQuery.of(context).size.width < 720;
    if (isCompact) {
      return _buildMobileAppBar(context, isDark, surfaceColor, borderColor);
    }
    return _buildDesktopAppBar(context, isDark, surfaceColor, borderColor);
  }

  Widget _buildTabItem(int index, PdfTab tab, bool isActive, bool isDark, Color borderColor) {
    final activeBg = isDark ? const Color(0xFF23262D) : const Color(0xFFFFFFFF);
    final inactiveBg = isDark ? const Color(0xFF16181C) : const Color(0xFFE9EEF4);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _activeTabIndex = index;
            });
            final currentTab = _tabs[index];
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _scrollToThumbnail(currentTab.currentPage);
              }
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 220, minWidth: 110),
            padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
            decoration: BoxDecoration(
              color: isActive ? activeBg : inactiveBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? primaryColor.withValues(alpha: 0.6) : borderColor,
                width: isActive ? 1.4 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 16,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tab.fileName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _closeTab(index),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark, Color surfaceColor, Color borderColor) {
    return Container(
      height: 44,
      color: isDark ? const Color(0xFF141619) : const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          // Folio Branding
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/icons/folio_icon_128.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Folio',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 12),
              Container(height: 18, width: 1, color: borderColor),
              const SizedBox(width: 8),
            ],
          ),

          // Scrollable Tabs
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length + 1,
              itemBuilder: (context, index) {
                if (index == _tabs.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: IconButton(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      tooltip: 'Yeni Belge Aç ($_modKey + O)',
                      onPressed: _isLoading ? null : _pickAndOpenFile,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                }

                final tab = _tabs[index];
                final isActive = index == _activeTabIndex;
                return _buildTabItem(index, tab, isActive, isDark, borderColor);
              },
            ),
          ),

          // Actions on right
          const SizedBox(width: 8),
          Container(height: 18, width: 1, color: borderColor),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
            ),
            tooltip: isDark ? 'Açık Mod' : 'Karanlık Mod',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopToolbar(bool isDark, Color surfaceColor, Color borderColor) {
    final activeTab = _activeTab;
    if (activeTab == null) return const SizedBox.shrink();

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // Sidebar Toggle
          IconButton(
            icon: Icon(
              _isSidebarVisible
                  ? Icons.view_sidebar_rounded
                  : Icons.view_sidebar_outlined,
              color: _isSidebarVisible
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: _isSidebarVisible
                ? 'Sayfa Önizlemeyi Gizle ($_modKey+B)'
                : 'Sayfa Önizlemeyi Göster ($_modKey+B)',
            onPressed: () {
              setState(() => _isSidebarVisible = !_isSidebarVisible);
            },
          ),
          const SizedBox(width: 4),
          Container(height: 18, width: 1, color: borderColor),
          const SizedBox(width: 8),

          // Page Navigation
          if (_totalPages > 0) ...[
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              tooltip: 'Önceki Sayfa (Sol Ok)',
              onPressed: _currentPage > 1 ? _goToPreviousPage : null,
            ),
            InkWell(
              onTap: _showPageJumpDialog,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF262930) : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              tooltip: 'Sonraki Sayfa (Sağ Ok)',
              onPressed: _currentPage < _totalPages ? _goToNextPage : null,
            ),
            const SizedBox(width: 8),
            Container(height: 18, width: 1, color: borderColor),
            const SizedBox(width: 8),
          ],

          // Zoom Controls
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 18),
            tooltip: 'Uzaklaştır ($_modKey + -)',
            onPressed: _zoomOut,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              '${(_zoomRatio * 100).round()}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 18),
            tooltip: 'Yakınlaştır ($_modKey + +)',
            onPressed: _zoomIn,
          ),
          const SizedBox(width: 4),

          // Fit Width
          IconButton(
            icon: const Icon(Icons.fit_screen_rounded, size: 18),
            tooltip: 'Genişliğe Sığdır ($_modKey + 0)',
            onPressed: _fitWidth,
          ),

          // Fit Page
          IconButton(
            icon: const Icon(Icons.fullscreen_rounded, size: 20),
            tooltip: 'Sayfaya Sığdır',
            onPressed: _fitPage,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 19),
            tooltip: 'Belgede Ara ($_modKey + F)',
            onPressed: _toggleSearch,
          ),

          const SizedBox(width: 4),
          Container(height: 18, width: 1, color: borderColor),
          const SizedBox(width: 6),
          _buildDesktopAnnotationTools(isDark, borderColor),

          const Spacer(),

          // Active Document Name tooltip
          Tooltip(
            message: activeTab.filePath,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.redAccent),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    activeTab.fileName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 18),
            tooltip: 'Paylaş',
            onPressed: _shareActiveDocument,
          ),
          IconButton(
            icon: const Icon(Icons.save_alt_rounded, size: 18),
            tooltip: 'Farklı Kaydet',
            onPressed: _saveActiveDocumentAs,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, size: 18),
            tooltip: 'Diğer İşlemler',
            onSelected: (value) {
              switch (value) {
                case 'move':
                  _moveActiveDocument();
                  break;
                case 'rename':
                  _renameActiveDocument();
                  break;
                case 'info':
                  _showDocumentInfo();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'move',
                child: Row(
                  children: [
                    Icon(Icons.drive_file_move_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Dosyayı Taşı...'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Yeniden Adlandır...'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Belge Bilgileri'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          Container(height: 18, width: 1, color: borderColor),
          const SizedBox(width: 6),

          // Close active tab
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Aktif Belgeyi Kapat ($_modKey + W)',
            onPressed: _closeDocument,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopAnnotationTools(bool isDark, Color borderColor) {
    final activeTab = _activeTab;
    if (activeTab == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    Widget buildToolBtn({
      required IconData icon,
      required String tooltip,
      required bool isSelected,
      required VoidCallback onTap,
      Color? activeColor,
    }) {
      final color = activeColor ?? primaryColor;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: color.withValues(alpha: 0.6),
                  width: 1.2,
                )
              : null,
        ),
        child: IconButton(
          icon: Icon(
            icon,
            size: 18,
            color: isSelected
                ? color
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
          tooltip: tooltip,
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      );
    }

    final isHighlighter = _activeAnnotationTool == AnnotationTool.highlighter;
    final isPen = _activeAnnotationTool == AnnotationTool.pen;
    final isEraser = _activeAnnotationTool == AnnotationTool.eraser;

    final highlighterColors = [
      const Color(0xFFFACC15), // Neon Yellow
      const Color(0xFF4ADE80), // Pastel Green
      const Color(0xFF60A5FA), // Soft Blue
      const Color(0xFFF472B6), // Bright Pink
      const Color(0xFFFB923C), // Orange
    ];

    final penColors = [
      const Color(0xFF2563EB), // Blue
      const Color(0xFFDC2626), // Red
      const Color(0xFF1E293B), // Dark Slate / Black
      const Color(0xFF16A34A), // Green
      const Color(0xFF9333EA), // Purple
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Navigation / Browse tool
        buildToolBtn(
          icon: Icons.near_me_rounded,
          tooltip: 'Gezinme / Seçim Modu',
          isSelected: _activeAnnotationTool == AnnotationTool.none,
          onTap: () => setState(() => _activeAnnotationTool = AnnotationTool.none),
        ),
        // Highlighter tool
        buildToolBtn(
          icon: Icons.border_color_rounded,
          tooltip: 'Vurgulayıcı Kalem',
          isSelected: isHighlighter,
          activeColor: const Color(0xFFEAB308),
          onTap: () {
            setState(() {
              _activeAnnotationTool = isHighlighter
                  ? AnnotationTool.none
                  : AnnotationTool.highlighter;
            });
          },
        ),
        // Pen tool
        buildToolBtn(
          icon: Icons.edit_rounded,
          tooltip: 'Kalemle Not Al / Çiz',
          isSelected: isPen,
          activeColor: const Color(0xFF2563EB),
          onTap: () {
            setState(() {
              _activeAnnotationTool =
                  isPen ? AnnotationTool.none : AnnotationTool.pen;
            });
          },
        ),
        // Eraser tool
        buildToolBtn(
          icon: Icons.auto_fix_normal_rounded,
          tooltip: 'Silgi (Çizime dokunarak sil)',
          isSelected: isEraser,
          activeColor: Colors.deepOrangeAccent,
          onTap: () {
            setState(() {
              _activeAnnotationTool =
                  isEraser ? AnnotationTool.none : AnnotationTool.eraser;
            });
          },
        ),

        // Color picker chips when Highlighter or Pen is active
        if (isHighlighter || isPen) ...[
          const SizedBox(width: 4),
          Container(height: 16, width: 1, color: borderColor),
          const SizedBox(width: 6),
          ...((isHighlighter ? highlighterColors : penColors).map((color) {
            final isColorSelected = isHighlighter
                ? _selectedHighlighterColor.toARGB32() == color.toARGB32()
                : _selectedPenColor.toARGB32() == color.toARGB32();
            return InkWell(
              onTap: () {
                setState(() {
                  if (isHighlighter) {
                    _selectedHighlighterColor = color;
                  } else {
                    _selectedPenColor = color;
                  }
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isColorSelected
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white24 : Colors.black12),
                    width: isColorSelected ? 2.2 : 1,
                  ),
                ),
              ),
            );
          })),
          const SizedBox(width: 4),
          // Stroke Width selection
          PopupMenuButton<double>(
            tooltip: 'Kalem Kalınlığı',
            icon: const Icon(Icons.line_weight_rounded, size: 17),
            padding: EdgeInsets.zero,
            splashRadius: 16,
            itemBuilder: (context) => isHighlighter
                ? [
                    const PopupMenuItem(
                        value: 16.0, child: Text('İnce Vurgu (16px)')),
                    const PopupMenuItem(
                        value: 24.0, child: Text('Normal Vurgu (24px)')),
                    const PopupMenuItem(
                        value: 36.0, child: Text('Geniş Vurgu (36px)')),
                  ]
                : [
                    const PopupMenuItem(
                        value: 1.5, child: Text('İnce Kalem (1.5px)')),
                    const PopupMenuItem(
                        value: 3.0, child: Text('Normal Kalem (3px)')),
                    const PopupMenuItem(
                        value: 5.5, child: Text('Kalın Kalem (5.5px)')),
                  ],
            onSelected: (width) {
              setState(() {
                if (isHighlighter) {
                  _highlighterWidth = width;
                } else {
                  _penWidth = width;
                }
              });
            },
          ),
        ],

        // Undo button
        if (activeTab.undoHistory.isNotEmpty) ...[
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.undo_rounded, size: 17),
            tooltip: 'Son Çizimi Geri Al',
            onPressed: () => _undoAnnotation(activeTab),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],

        // Clear Page button
        if (activeTab.annotations.containsKey(_currentPage) &&
            (activeTab.annotations[_currentPage]?.isNotEmpty ?? false)) ...[
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, size: 17),
            tooltip: 'Bu Sayfadaki Çizimleri Temizle',
            onPressed: () =>
                _confirmClearPageAnnotations(activeTab, _currentPage),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: Colors.redAccent,
          ),
        ],
      ],
    );
  }

  PreferredSizeWidget _buildDesktopAppBar(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    if (_tabs.isEmpty) {
      return AppBar(
        toolbarHeight: 56,
        backgroundColor: surfaceColor,
        shape: Border(bottom: BorderSide(color: borderColor, width: 1)),
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/icons/folio_icon_128.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Folio',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton.tonalIcon(
            onPressed: _isLoading ? null : _pickAndOpenFile,
            icon: const Icon(Icons.file_open_rounded, size: 18),
            label: const Text('Dosya Aç'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            tooltip: isDark ? 'Açık Mod' : 'Karanlık Mod',
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 10),
        ],
      );
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(90),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabBar(isDark, surfaceColor, borderColor),
          _buildDesktopToolbar(isDark, surfaceColor, borderColor),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    if (_tabs.isEmpty) {
      return AppBar(
        toolbarHeight: 56,
        backgroundColor: surfaceColor,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: borderColor, width: 1)),
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/icons/folio_icon_128.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Folio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            tooltip: isDark ? 'Açık Mod' : 'Karanlık Mod',
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 6),
        ],
      );
    }

    final activeTab = _activeTab;
    return AppBar(
      toolbarHeight: 56,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: borderColor, width: 1)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Belgeyi Kapat',
        onPressed: _closeDocument,
      ),
      titleSpacing: 0,
      title: Text(
        activeTab?.fileName ?? '',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      bottom: _tabs.length > 1
          ? PreferredSize(
              preferredSize: const Size.fromHeight(36),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tabs.length,
                  itemBuilder: (context, index) {
                    final tab = _tabs[index];
                    final isActive = index == _activeTabIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          tab.fileName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isActive,
                        onSelected: (_) => setState(() => _activeTabIndex = index),
                      ),
                    );
                  },
                ),
              ),
            )
          : null,
      actions: [
        if (_totalPages > 0) ...[
          InkWell(
            onTap: _showPageJumpDialog,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262930) : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded, size: 21),
            tooltip: 'Sayfa Önizlemeleri',
            onPressed: () => _showThumbnailsBottomSheet(context),
          ),
        ],
        IconButton(
          icon: const Icon(Icons.search_rounded, size: 21),
          tooltip: 'Belgede Ara',
          onPressed: _toggleSearch,
        ),
        IconButton(
          icon: Icon(
            _activeAnnotationTool == AnnotationTool.none
                ? Icons.edit_note_rounded
                : (_activeAnnotationTool == AnnotationTool.highlighter
                    ? Icons.border_color_rounded
                    : Icons.edit_rounded),
            size: 21,
            color: _activeAnnotationTool != AnnotationTool.none
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          tooltip: 'Vurgulayıcı & Kalem',
          onPressed: () => _showMobileAnnotationBottomSheet(context, activeTab),
        ),
        IconButton(
          icon: const Icon(Icons.share_rounded, size: 21),
          tooltip: 'Paylaş',
          onPressed: _shareActiveDocument,
        ),
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 21,
          ),
          tooltip: isDark ? 'Açık Mod' : 'Karanlık Mod',
          onPressed: widget.onToggleTheme,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            switch (value) {
              case 'share':
                _shareActiveDocument();
                break;
              case 'save_as':
                _saveActiveDocumentAs();
                break;
              case 'move':
                _moveActiveDocument();
                break;
              case 'rename':
                _renameActiveDocument();
                break;
              case 'info':
                _showDocumentInfo();
                break;
              case 'open':
                _pickAndOpenFile();
                break;
              case 'zoom_in':
                _zoomIn();
                break;
              case 'zoom_out':
                _zoomOut();
                break;
              case 'fit_width':
                _fitWidth();
                break;
              case 'fit_page':
                _fitPage();
                break;
              case 'close':
                _closeDocument();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share_rounded, size: 18, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text('Paylaş (WhatsApp, vb.)'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'save_as',
              child: Row(
                children: [
                  Icon(Icons.save_alt_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Farklı Kaydet...'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'move',
              child: Row(
                children: [
                  Icon(Icons.drive_file_move_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Dosyayı Taşı...'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Yeniden Adlandır...'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Belge Bilgileri'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.file_open_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Yeni Belge Aç'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'zoom_in',
              child: Row(
                children: [
                  Icon(Icons.zoom_in_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Yakınlaştır'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'zoom_out',
              child: Row(
                children: [
                  Icon(Icons.zoom_out_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Uzaklaştır'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'fit_width',
              child: Row(
                children: [
                  Icon(Icons.fit_screen_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Genişliğe Sığdır'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'fit_page',
              child: Row(
                children: [
                  Icon(Icons.fullscreen_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Sayfaya Sığdır'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'close',
              child: Row(
                children: [
                  Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text('Belgeyi Kapat', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyView(bool isDark) {
    final cardColor = isDark
        ? const Color(0xFF1B1D22)
        : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? const Color(0xFF2E323B)
        : const Color(0xFFE2E8F0);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB)
                              .withValues(alpha: isDark ? 0.35 : 0.2),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/icons/folio_icon_256.png',
                        width: 92,
                        height: 92,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Folio',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF3B82F6)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'PDF',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3B82F6),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isMobile
                        ? 'Minimalist ve akıcı PDF okuyucu.\nGörüntülemek için bir PDF belgesi seçin.'
                        : 'Minimalist, akıcı ve yüksek performanslı belge okuyucu.\nGörüntülemek için bir PDF belgesi seçin veya doğrudan açın.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _pickAndOpenFile,
                    icon: const Icon(Icons.file_open_rounded, size: 20),
                    label: const Text(
                      'PDF Dosyası Seç',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (!_isMobile) ...[
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF14161A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildShortcutHint('$_modKey + O', 'Dosya Aç', isDark),
                          _buildShortcutHint('$_modKey + B', 'Önizleme', isDark),
                          _buildShortcutHint(
                              '$_modKey + +/-', 'Yakınlaştır', isDark),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_recentDocuments.isNotEmpty)
            RecentDocumentsView(
              recentDocuments: _recentDocuments,
              onOpenFile: (path) => _checkAndOpenFile(path),
              onRemoveFile: (path) async {
                await RecentDocumentsService.removeDocument(path);
                _loadRecentDocuments();
              },
              onClearAll: () async {
                await RecentDocumentsService.clearAll();
                _loadRecentDocuments();
              },
              isDark: isDark,
            ),
        ],
      ),
    ),
  );
}

  Widget _buildShortcutHint(String keys, String label, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF282B32) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            keys,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildPdfView(bool isDark) {
    final sidebarBg = isDark
        ? const Color(0xFF16181C)
        : const Color(0xFFF9FAFB);
    final borderColor = isDark
        ? const Color(0xFF272A32)
        : const Color(0xFFE5E7EB);

    return Row(
      children: [
        // Collapsible Thumbnail Sidebar (only embedded on desktop)
        if (!_isMobile)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: _isSidebarVisible ? 220 : 0,
            child: ClipRect(
              child: OverflowBox(
                minWidth: 220,
                maxWidth: 220,
                alignment: Alignment.topLeft,
                child: Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: sidebarBg,
                    border: Border(right: BorderSide(color: borderColor)),
                  ),
                  child: _buildThumbnailPanel(isDark, borderColor),
                ),
              ),
            ),
          ),

        // Main PDF Canvas with Multi-Document Tabs
        Expanded(
          child: Stack(
            children: [
              Container(
                color: isDark
                    ? const Color(0xFF0F1012)
                    : const Color(0xFFE5E7EB),
                child: IndexedStack(
                  index: _activeTabIndex >= 0 ? _activeTabIndex : 0,
                  children: _tabs
                      .map((tab) => _buildPdfViewerForTab(tab, isDark))
                      .toList(),
                ),
              ),
              if (_isSearchVisible)
                Positioned(
                  top: 12,
                  right: _isMobile ? 12 : 24,
                  left: _isMobile ? 12 : null,
                  child: _buildSearchBar(isDark, borderColor),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark, Color borderColor) {
    final searcher = _activeTab?.textSearcher;
    final matchCount = searcher?.matches.length ?? 0;
    final currentIndex = searcher?.currentIndex;
    final isSearching = searcher?.isSearching ?? false;

    String matchText = '';
    if (_searchController.text.trim().isNotEmpty) {
      if (isSearching) {
        matchText = 'Aranıyor...';
      } else if (matchCount == 0) {
        matchText = '0 sonuç';
      } else {
        matchText = '${(currentIndex ?? 0) + 1} / $matchCount';
      }
    }

    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;

    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.25),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: _isMobile ? double.infinity : 380,
          minWidth: 260,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_rounded, size: 20, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Belgede ara...',
                  hintStyle: TextStyle(fontSize: 13),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) {
                  if (HardwareKeyboard.instance.isShiftPressed) {
                    _searchPrev();
                  } else {
                    _searchNext();
                  }
                },
              ),
            ),
            if (matchText.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C3038) : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  matchText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: matchCount > 0
                        ? (isDark ? Colors.lightBlueAccent : Colors.blue.shade700)
                        : Colors.grey,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
              tooltip: 'Önceki (Shift+Enter)',
              onPressed: matchCount > 0 ? _searchPrev : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              tooltip: 'Sonraki (Enter)',
              onPressed: matchCount > 0 ? _searchNext : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Kapat (Esc)',
              onPressed: _closeSearch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfViewerForTab(PdfTab tab, bool isDark) {
    return PdfViewer.file(
      tab.filePath,
      key: ValueKey(tab.id),
      controller: tab.controller,
      params: PdfViewerParams(
        panEnabled: _activeAnnotationTool == AnnotationTool.none,
        scrollPhysics: _activeAnnotationTool == AnnotationTool.none
            ? null
            : const NeverScrollableScrollPhysics(),
        pagePaintCallbacks: [
          (canvas, pageRect, page) {
            tab.textSearcher?.pageTextMatchPaintCallback(canvas, pageRect, page);
          },
        ],
        pageOverlaysBuilder: (context, rectExternal, page) => [
          PdfPageAnnotationOverlay(
            pageNumber: page.pageNumber,
            pageSize: Size(rectExternal.width, rectExternal.height),
            strokes: tab.annotations[page.pageNumber] ?? [],
            activeTool: _activeAnnotationTool,
            selectedColor: _activeAnnotationTool == AnnotationTool.highlighter
                ? _selectedHighlighterColor
                : _selectedPenColor,
            strokeWidth: _activeAnnotationTool == AnnotationTool.highlighter
                ? _highlighterWidth
                : _penWidth,
            onStrokeAdded: (stroke) =>
                _onStrokeAdded(tab, page.pageNumber, stroke),
            onErase: (localPos) => _onEraseAtPoint(
              tab,
              page.pageNumber,
              localPos,
              Size(rectExternal.width, rectExternal.height),
            ),
          ),
        ],
        backgroundColor: isDark
            ? const Color(0xFF0F1012)
            : const Color(0xFFE5E7EB),
        pageDropShadow: BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        margin: 16,
        viewerOverlayBuilder: (context, size, handleLinkTap) => [
          PdfViewerScrollThumb(
            controller: tab.controller,
            orientation: ScrollbarOrientation.right,
            thumbSize: const Size(32, 48),
            margin: 6,
            thumbBuilder: (context, thumbSize, pageNumber, controller) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2E333D).withValues(alpha: 0.92)
                      : const Color(0xFF1E293B).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${pageNumber ?? 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          PdfViewerScrollThumb(
            controller: tab.controller,
            orientation: ScrollbarOrientation.bottom,
            thumbSize: const Size(48, 8),
            margin: 4,
            thumbBuilder: (context, thumbSize, pageNumber, controller) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3B404D).withValues(alpha: 0.6)
                      : const Color(0xFF64748B).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            },
          ),
        ],
        errorBannerBuilder: (context, error, stackTrace, documentRef) {
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2024) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 52,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'PDF Açılamadı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bu dosya geçerli veya okunabilir bir PDF formatında değil (FPDF_ERR_FORMAT).\nLütfen geçerli bir PDF belgesi seçin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => _closeTab(_tabs.indexOf(tab)),
                        child: const Text('Kapat'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _pickAndOpenFile,
                        icon: const Icon(Icons.file_open_rounded, size: 18),
                        label: const Text('Başka Dosya Seç'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        onViewerReady: (document, controller) {
          tab.document = document;
          tab.totalPages = document.pages.length;
          if (tab.textSearcher == null) {
            tab.textSearcher = PdfTextSearcher(controller);
            tab.textSearcher!.addListener(() {
              if (mounted && _activeTab == tab) {
                setState(() {});
              }
            });
            if (_isSearchVisible && _searchController.text.trim().isNotEmpty) {
              tab.textSearcher!.startTextSearch(_searchController.text.trim());
            }
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !controller.isReady) return;
            final matrix = controller.calcMatrixFitWidthForPage(pageNumber: tab.currentPage);
            if (matrix != null) {
              controller.value = matrix;
            }
            setState(() {
              tab.zoomRatio = controller.currentZoom;
            });
          });
        },
        onPageChanged: (pageNumber) {
          if (pageNumber != null && pageNumber != tab.currentPage) {
            setState(() {
              tab.currentPage = pageNumber;
            });
            if (tab == _activeTab) {
              _scrollToThumbnail(pageNumber);
            }
          }
        },
      ),
    );
  }

  Widget _buildThumbnailPanel(bool isDark, Color borderColor) {
    if (_document == null || _totalPages == 0) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    return Column(
      children: [
        // Sidebar Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
          child: Row(
            children: [
              const Icon(Icons.grid_view_rounded, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Sayfalar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF262930)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_totalPages',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: borderColor),

        // Thumbnail List
        Expanded(
          child: ListView.builder(
            controller: _thumbnailScrollController,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            itemCount: _totalPages,
            itemBuilder: (context, index) {
              final pageNumber = index + 1;
              final isSelected = pageNumber == _currentPage;

              return InkWell(
                onTap: () {
                  _pdfController?.goToPage(pageNumber: pageNumber);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                            : const Color(0xFFDBEAFE))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          color: Colors.white,
                          child: SizedBox(
                            height: 140,
                            child: PdfPageView(
                              document: _document,
                              pageNumber: pageNumber,
                              maximumDpi: 100,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$pageNumber',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
