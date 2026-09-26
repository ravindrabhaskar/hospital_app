import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../theme/tokens.dart';
import '../utils/format.dart';
import '../utils/save_file/save_file.dart';
import 'common.dart';
import 'state_views.dart';

/// Opens [PdfViewerScreen] on the root navigator.
Future<void> openPdf(
  BuildContext context, {
  required String title,
  required String fileName,
  required Future<List<int>> Function() load,
}) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      builder: (_) => PdfViewerScreen(title: title, fileName: fileName, load: load),
    ));

/// In-app PDF viewer (pdfx: Android PdfRenderer / iOS CGPDF).
///
/// On web the app does not load PDF.js from a CDN, so the downloaded file is
/// opened in the browser's own viewer in a new tab (a user tap, so pop-up
/// blockers allow it) or downloaded.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.title, required this.fileName, required this.load});
  final String title;
  final String fileName;
  final Future<List<int>> Function() load;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _bytes;
  Object? _error;
  PdfControllerPinch? _controller;
  int _page = 1;
  int _pages = 0;

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
      if (!kIsWeb) c = PdfControllerPinch(document: PdfDocument.openData(bytes));
      _controller?.dispose();
      setState(() {
        _bytes = bytes;
        _controller = c;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final b = _bytes;
    if (b == null) return;
    try {
      await saveOrShareFile(bytes: b, fileName: widget.fileName, mimeType: 'application/pdf', subject: widget.title);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_bytes != null)
            IconButton(
              tooltip: kIsWeb ? l.download : l.share,
              onPressed: _share,
              icon: Icon(kIsWeb ? Icons.download_outlined : Icons.ios_share),
            ),
        ],
      ),
      body: _error != null
          ? ErrorStateView(error: _error!, onRetry: _fetch)
          : _bytes == null
              ? const LoadingView()
              : kIsWeb || c == null
                  ? _WebPdfFallback(bytes: _bytes!, onDownload: _share)
                  : Column(
                      children: [
                        Expanded(
                          child: Semantics(
                            label: l.pdfDocument(widget.title),
                            child: PdfViewPinch(
                              controller: c,
                              onDocumentLoaded: (d) => setState(() => _pages = d.pagesCount),
                              onPageChanged: (p) => setState(() => _page = p),
                              builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                                options: const DefaultBuilderOptions(),
                                errorBuilder: (_, e) => ErrorStateView(error: e, onRetry: _fetch),
                              ),
                            ),
                          ),
                        ),
                        if (_pages > 0)
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.all(Space.sm),
                              child: Text(l.pageOf(_page, _pages),
                                  style: TextStyle(color: context.textMuted, fontSize: 12)),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class _WebPdfFallback extends StatelessWidget {
  const _WebPdfFallback({required this.bytes, required this.onDownload});
  final Uint8List bytes;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(Space.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconTile(icon: Icons.picture_as_pdf_outlined, accent: Accent.rose, size: 72),
              const SizedBox(height: Space.lg),
              Text(l.pdfReady(fmtBytes(bytes.length)),
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Space.sm),
              Text(l.pdfWebNote, textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
              const SizedBox(height: Space.xl),
              PrimaryButton(
                label: l.openPdfInNewTab,
                icon: Icons.open_in_new,
                onPressed: () async {
                  final ok = await openBytesInNewTab(bytes: bytes, mimeType: 'application/pdf');
                  if (!ok && context.mounted) showSnack(context, l.previewUnavailable);
                },
              ),
              const SizedBox(height: Space.sm),
              OutlinedButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_outlined),
                label: Text(l.download),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
