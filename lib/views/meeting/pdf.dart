import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewPage extends StatefulWidget {
  final String filePath;

  PdfViewPage({required this.filePath});

  @override
  _PdfViewPageState createState() => _PdfViewPageState();
}

class _PdfViewPageState extends State<PdfViewPage> {
  bool _isReady = false;
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PDF Viewer')),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.filePath,
            onRender: (_) => setState(() => _isReady = true),
            onError: (e) => setState(() => _error = e.toString()),
            onPageError: (_, e) => setState(() => _error = e.toString()),
          ),
          if (!_isReady) const Center(child: CircularProgressIndicator()),
          if (_error.isNotEmpty) Center(child: Text('Error: $_error')),
        ],
      ),
    );
  }
}
