import 'dart:io';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/ai_chat/presentation/message/ai_markdown_text.dart';
import 'package:appflowy/plugins/local_file/local_file.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:pdfx/pdfx.dart';

enum FileType {
  markdown,
  plainText,
  pdf,
  unsupported,
}

class LocalFilePage extends StatefulWidget {
  const LocalFilePage({
    super.key,
    required this.fileData,
  });

  final LocalFileData fileData;

  @override
  State<LocalFilePage> createState() => _LocalFilePageState();
}

class _LocalFilePageState extends State<LocalFilePage> {
  String? _fileContent;
  bool _isLoading = true;
  FileType _fileType = FileType.unsupported;
  String? _error;

  // PDF specific variables
  PdfController? _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    try {
      final file = File(widget.fileData.filePath);
      if (!await file.exists()) {
        setState(() {
          _error = LocaleKeys.localFile_fileNotFound
              .tr(args: [widget.fileData.filePath]);
          _isLoading = false;
        });
        return;
      }

      // Check file extension to determine file type
      final extension = path.extension(widget.fileData.filePath).toLowerCase();

      switch (extension) {
        case '.md':
        case '.markdown':
          // Handle markdown files
          final content = await file.readAsString();
          setState(() {
            _fileContent = content;
            _fileType = FileType.markdown;
            _isLoading = false;
          });
          break;
        case '.txt':
          // Handle plain text files
          final content = await file.readAsString();
          setState(() {
            _fileContent = content;
            _fileType = FileType.plainText;
            _isLoading = false;
          });
          break;
        case '.pdf':
          // Handle PDF files
          try {
            _pdfController = PdfController(
              document: PdfDocument.openFile(widget.fileData.filePath),
              // initialPage: 1,
            );
            final pagesCount = _pdfController!.pagesCount;
            setState(() {
              _fileType = FileType.pdf;
              _totalPages = pagesCount ?? 0;
              _isLoading = false;
            });
          } catch (e) {
            setState(() {
              _error = LocaleKeys.localFile_errorLoadingPDF.tr(args: ['$e']);
              _isLoading = false;
            });
          }
          break;
        default:
          // Unsupported file type
          setState(() {
            _fileContent = null;
            _fileType = FileType.unsupported;
            _isLoading = false;
          });
      }
    } catch (e) {
      setState(() {
        _error = LocaleKeys.localFile_errorLoadingFile.tr(args: ['$e']);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          FlowySvg(
            FlowySvgs.page_m,
            size: const Size.square(24),
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fileData.fileName,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    if (_fileType == FileType.pdf && _totalPages > 0) ...[
                      FlowyText(
                        LocaleKeys.localFile_pageCount
                            .tr(args: ['$_currentPage', '$_totalPages']),
                        color: Theme.of(context).hintColor,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_fileType) {
      case FileType.markdown:
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: AIMarkdownText(
              markdown: _fileContent!,
            ),
          ),
        );
      case FileType.plainText:
        return Container(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withAlpha(50),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _fileContent!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
            ),
          ),
        );
      case FileType.pdf:
        if (_pdfController == null) {
          return Center(
            child: Text(LocaleKeys.localFile_failedToLoadPDF.tr()),
          );
        }
        return PdfView(
          controller: _pdfController!,
          scrollDirection: Axis.vertical,
          pageSnapping: false,
          onDocumentLoaded: (document) {
            setState(() {
              _totalPages = document.pagesCount;
            });
          },
          onPageChanged: (page) {
            setState(() {
              _currentPage = page;
            });
          },
          builders: PdfViewBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(),
            documentLoaderBuilder: (_) => const Center(
              child: CircularProgressIndicator(),
            ),
            pageLoaderBuilder: (_) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorBuilder: (_, error) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    LocaleKeys.localFile_errorLoadingPDFWithMessage
                        .tr(args: ['$error']),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      case FileType.unsupported:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FlowySvg(
                FlowySvgs.page_m,
                size: const Size.square(16),
                color: Theme.of(context).hintColor,
              ),
              const SizedBox(height: 16),
              Text(
                LocaleKeys.localFile_previewNotAvailable.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                LocaleKeys.localFile_fileTypeCannotBeDisplayed.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  // Open the file externally if needed
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        LocaleKeys.localFile_openExternallyNotImplemented.tr(),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: Text(LocaleKeys.localFile_openExternally.tr()),
              ),
            ],
          ),
        );
    }
  }
}
