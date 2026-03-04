import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

class PdfPreview extends StatefulWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const PdfPreview({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  State<PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  late PdfController pdfController;

  int _pageNumber = 1;
  int _totalPages = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      final tempDir = await getApplicationCacheDirectory();

      final file = File(
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.pdf');

      await file.writeAsBytes(widget.pdfBytes);

      pdfController = PdfController(
        document: PdfDocument.openFile(file.path),
      );

      final doc = await PdfDocument.openFile(file.path);

      if (mounted) {
        setState(() {
          _totalPages = doc.pagesCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading PDF: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      pdfController.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            widget.fileName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      );
    }

    return Column(
      children: [
        Text(
          widget.fileName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 8),

        // FULL HEIGHT PDF VIEWER
        Expanded(
          child: PdfView(
            controller: pdfController,
            onPageChanged: (page) {
              setState(() {
                _pageNumber = page ?? 0;
              });
            },
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Page $_pageNumber of $_totalPages',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}