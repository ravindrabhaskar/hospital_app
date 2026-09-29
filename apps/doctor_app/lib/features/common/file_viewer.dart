import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/theme.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';
import 'platform/platform_files.dart';

/// Opens a PDF or image fetched with [load] (prescription PDFs, original
/// record files) on the root navigator.
Future<void> openFile(
  BuildContext context, {
  required String title,
  required Future<List<int>> Function() load,
  String mimeType = 'application/pdf',
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    builder: (_) => FileViewerScreen(title: title, load: load, mimeType: mimeType),
  ),
);

/// In-app viewer: pdfx for PDFs on mobile, Image.memory for images. On web
/// PDFs open in the browser's own viewer (no PDF.js from a CDN).
class FileViewerScreen extends StatefulWidget {
  const FileViewerScreen({super.key, required this.title, required this.load, required this.mimeType});
  final String title;
  final Future<List<int>> Function() load;
  final String mimeType;

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  Uint8List? _bytes;
  Object? _error;
  PdfControllerPinch? _pdf;
  int _page = 1;
  int _pages = 0;

  bool get _isPdf => widget.mimeType.contains('pdf');
  bool get _isImage => widget.mimeType.startsWith('image/');

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _error = null;
      _bytes = null;
    });
    try {
      final bytes = Uint8List.fromList(await widget.load());
      if (!mounted) return;
      PdfControllerPinch? c;
      if (_isPdf && !kIsWeb) c = PdfControllerPinch(document: PdfDocument.openData(bytes));
      _pdf?.dispose();
      setState(() {
        _bytes = bytes;
        _pdf = c;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget body;
    if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _fetch);
    } else if (_bytes == null) {
      body = const LoadingView();
    } else if (_isImage) {
      body = InteractiveViewer(
        child: Center(child: Image.memory(_bytes!, semanticLabel: widget.title)),
      );
    } else if (_pdf != null) {
      body = Column(
        children: [
          Expanded(
            child: Semantics(
              label: l.pdfDocument(widget.title),
              child: PdfViewPinch(
                controller: _pdf!,
                onDocumentLoaded: (d) => setState(() => _pages = d.pagesCount),
                onPageChanged: (p) => setState(() => _page = p),
              ),
            ),
          ),
          if (_pages > 0)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(l.pageOf(_page, _pages), style: const TextStyle(color: AppColors.textSecondary)),
              ),
            ),
        ],
      );
    } else {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 56, color: AppColors.danger),
              gap12,
              Text(l.fileReady, textAlign: TextAlign.center),
              gap16,
              FilledButton.icon(
                onPressed: () async {
                  final ok = await openBytesInBrowser(_bytes!, widget.mimeType);
                  if (!ok && context.mounted) showSnack(context, l.linkFailed);
                },
                icon: const Icon(Icons.open_in_new),
                label: Text(l.openInBrowser),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: body,
    );
  }
}
