import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();

  String? initialFilePath;
  if (args.isNotEmpty) {
    final candidate = args.first.replaceAll('"', '').trim();
    if (candidate.isNotEmpty && File(candidate).existsSync()) {
      initialFilePath = candidate;
    }
  }

  runApp(PdfReaderApp(initialFilePath: initialFilePath));
}

class PdfReaderApp extends StatefulWidget {
  final String? initialFilePath;

  const PdfReaderApp({super.key, this.initialFilePath});

  @override
  State<PdfReaderApp> createState() => _PdfReaderAppState();
}

class _PdfReaderAppState extends State<PdfReaderApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class PdfViewerHomeScreen extends StatefulWidget {
  final String? initialFilePath;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const PdfViewerHomeScreen({
    super.key,
    this.initialFilePath,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<PdfViewerHomeScreen> createState() => _PdfViewerHomeScreenState();
}

class _PdfViewerHomeScreenState extends State<PdfViewerHomeScreen> {
  String? _filePath;
  PdfViewerController? _pdfController;
  PdfDocument? _document;

  int _currentPage = 1;
  int _totalPages = 0;
  double _zoomRatio = 1.0;
  bool _isSidebarVisible = true;
  bool _isLoading = false;

  final ScrollController _thumbnailScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _pdfController!.addListener(_onControllerUpdate);

    if (widget.initialFilePath != null) {
      _checkAndOpenFile(widget.initialFilePath!);
    }
  }

  @override
  void dispose() {
    _pdfController?.removeListener(_onControllerUpdate);
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted || _pdfController == null) return;

    final newZoom = _pdfController!.currentZoom;
    if ((newZoom - _zoomRatio).abs() > 0.01) {
      setState(() {
        _zoomRatio = newZoom;
      });
    }

    final newPage = _pdfController!.pageNumber;
    if (newPage != null && newPage != _currentPage) {
      setState(() {
        _currentPage = newPage;
      });
      _scrollToThumbnail(newPage);
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
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        dialogTitle: 'Bir PDF Dosyası Seçin',
      );

      if (file != null && file.path != null) {
        _checkAndOpenFile(file.path!);
      }
    } catch (e) {
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

  void _checkAndOpenFile(String path) {
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
    setState(() {
      _filePath = path;
      _currentPage = 1;
      _totalPages = 0;
      _document = null;
      _zoomRatio = 1.0;
    });
  }

  void _closeDocument() {
    setState(() {
      _filePath = null;
      _document = null;
      _currentPage = 1;
      _totalPages = 0;
      _zoomRatio = 1.0;
    });
  }

  void _zoomIn() {
    _pdfController?.zoomUp();
  }

  void _zoomOut() {
    _pdfController?.zoomDown();
  }

  void _resetZoom() {
    if (_pdfController != null && _pdfController!.isReady) {
      _pdfController!.goToPage(pageNumber: _currentPage);
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? const Color(0xFF1E2024)
        : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? const Color(0xFF2C2F36)
        : const Color(0xFFE5E7EB);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _pickAndOpenFile,
        const SingleActivator(LogicalKeyboardKey.equal, control: true):
            _zoomIn,
        const SingleActivator(LogicalKeyboardKey.minus, control: true):
            _zoomOut,
        const SingleActivator(LogicalKeyboardKey.digit0, control: true):
            _resetZoom,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
          setState(() => _isSidebarVisible = !_isSidebarVisible);
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _goToPreviousPage,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _goToNextPage,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: _buildAppBar(isDark, surfaceColor, borderColor),
          body: _filePath == null ? _buildEmptyView(isDark) : _buildPdfView(isDark),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      bool isDark, Color surfaceColor, Color borderColor) {
    final fileName = _filePath != null ? _getFileName(_filePath!) : null;

    return AppBar(
      toolbarHeight: 58,
      backgroundColor: surfaceColor,
      shape: Border(bottom: BorderSide(color: borderColor, width: 1)),
      titleSpacing: 12,
      title: Row(
        children: [
          // If no document is open, show Folio brand badge
          if (_filePath == null) ...[
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
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 14),
            Container(height: 18, width: 1, color: borderColor),
            const SizedBox(width: 12),
          ],

          // Sidebar Toggle Button
          if (_filePath != null) ...[
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
                  ? 'Sayfa Önizlemeyi Gizle (Ctrl+B)'
                  : 'Sayfa Önizlemeyi Göster (Ctrl+B)',
              onPressed: () {
                setState(() => _isSidebarVisible = !_isSidebarVisible);
              },
            ),
            const SizedBox(width: 4),
          ],

          // "Dosya Aç" Button
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

          if (fileName != null) ...[
            const SizedBox(width: 12),
            Container(height: 20, width: 1, color: borderColor),
            const SizedBox(width: 12),
            // File Name & Path Tooltip
            Expanded(
              child: Tooltip(
                message: _filePath!,
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            const Spacer(),

          // Page Number Indicator
          if (_filePath != null && _totalPages > 0) ...[
            Container(height: 20, width: 1, color: borderColor),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Önceki Sayfa (Sol Ok)',
              onPressed: _currentPage > 1 ? _goToPreviousPage : null,
            ),
            InkWell(
              onTap: _showPageJumpDialog,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF262930)
                      : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Sonraki Sayfa (Sağ Ok)',
              onPressed:
                  _currentPage < _totalPages ? _goToNextPage : null,
            ),
            const SizedBox(width: 8),
          ],

          // Zoom Controls
          if (_filePath != null) ...[
            Container(height: 20, width: 1, color: borderColor),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.remove_rounded, size: 20),
              tooltip: 'Uzaklaştır (Ctrl + -)',
              onPressed: _zoomOut,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '${(_zoomRatio * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 20),
              tooltip: 'Yakınlaştır (Ctrl + +)',
              onPressed: _zoomIn,
            ),
            IconButton(
              icon: const Icon(Icons.fit_screen_rounded, size: 20),
              tooltip: 'Genişliğe Sığdır (Ctrl + 0)',
              onPressed: _resetZoom,
            ),
            const SizedBox(width: 8),
          ],

          // Theme Toggle
          Container(height: 20, width: 1, color: borderColor),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            tooltip: widget.isDarkMode ? 'Açık Mod' : 'Karanlık Mod',
            onPressed: widget.onToggleTheme,
          ),

          // Close File Button
          if (_filePath != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Belgeyi Kapat',
              onPressed: _closeDocument,
            ),
          ],
        ],
      ),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(36),
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
                      color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.35 : 0.2),
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
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
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
                'Minimalist, akıcı ve yüksek performanslı belge okuyucu.\nGörüntülemek için bir PDF belgesi seçin veya doğrudan açın.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _pickAndOpenFile,
                icon: const Icon(Icons.file_open_rounded, size: 20),
                label: const Text(
                  'PDF Dosyası Seç',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                    _buildShortcutHint('Ctrl + O', 'Dosya Aç', isDark),
                    _buildShortcutHint('Ctrl + B', 'Önizleme', isDark),
                    _buildShortcutHint('Ctrl + +/-', 'Yakınlaştır', isDark),
                  ],
                ),
              ),
            ],
          ),
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
        // Collapsible Thumbnail Sidebar
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: _isSidebarVisible ? 220 : 0,
          child: _isSidebarVisible
              ? Container(
                  decoration: BoxDecoration(
                    color: sidebarBg,
                    border: Border(right: BorderSide(color: borderColor)),
                  ),
                  child: _buildThumbnailPanel(isDark, borderColor),
                )
              : const SizedBox.shrink(),
        ),

        // Main PDF Canvas
        Expanded(
          child: Container(
            color: isDark
                ? const Color(0xFF0F1012)
                : const Color(0xFFE5E7EB),
            child: PdfViewer.file(
              _filePath!,
              controller: _pdfController,
              params: PdfViewerParams(
                backgroundColor: isDark
                    ? const Color(0xFF0F1012)
                    : const Color(0xFFE5E7EB),
                pageDropShadow: BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                margin: 16,
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
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton(
                                onPressed: _closeDocument,
                                child: const Text('Kapat'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: _pickAndOpenFile,
                                icon: const Icon(Icons.file_open_rounded,
                                    size: 18),
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
                  setState(() {
                    _document = document;
                    _totalPages = document.pages.length;
                  });
                },
                onPageChanged: (pageNumber) {
                  if (pageNumber != null && pageNumber != _currentPage) {
                    setState(() {
                      _currentPage = pageNumber;
                    });
                    _scrollToThumbnail(pageNumber);
                  }
                },
              ),
            ),
          ),
        ),
      ],
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
