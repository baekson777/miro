import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/legal_document.dart';

/// In-app viewer for Privacy Policy / Terms (KO + EN for Play review).
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.type,
    this.initialLanguage = LegalLanguage.ko,
  });

  final LegalDocumentType type;
  final LegalLanguage initialLanguage;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late LegalLanguage _lang = widget.initialLanguage;
  Future<String>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<String> _load() {
    return rootBundle.loadString(widget.type.assetPath(_lang));
  }

  void _setLang(LegalLanguage lang) {
    if (_lang == lang) return;
    setState(() {
      _lang = lang;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type.title(_lang)),
        actions: [
          TextButton(
            onPressed: () => _setLang(LegalLanguage.ko),
            child: Text(
              '한국어',
              style: TextStyle(
                fontWeight:
                    _lang == LegalLanguage.ko ? FontWeight.w700 : FontWeight.w500,
                color: _lang == LegalLanguage.ko
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white70,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _setLang(LegalLanguage.en),
            child: Text(
              'EN',
              style: TextStyle(
                fontWeight:
                    _lang == LegalLanguage.en ? FontWeight.w700 : FontWeight.w500,
                color: _lang == LegalLanguage.en
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white70,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('문서를 불러오지 못했습니다.\n${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _MarkdownLiteView(text: snap.data!);
        },
      ),
    );
  }
}

/// Lightweight markdown-ish renderer (headings / bullets / paragraphs).
class _MarkdownLiteView extends StatelessWidget {
  const _MarkdownLiteView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = text.split(RegExp(r'\n{2,}'));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final block = blocks[index].trim();
        if (block.isEmpty) return const SizedBox.shrink();

        if (block.startsWith('# ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Text(
              block.substring(2).trim(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }
        if (block.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              block.substring(3).trim(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          );
        }
        if (block.startsWith('### ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              block.substring(4).trim(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final lines = block.split('\n');
        final isList = lines.every(
          (l) => l.trim().isEmpty || l.trimLeft().startsWith('- '),
        );
        if (isList) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  if (line.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ', style: TextStyle(height: 1.45)),
                          Expanded(
                            child: Text(
                              line.trimLeft().substring(2).trim(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.45,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            block.replaceAll('\n', ' '),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: Colors.white70,
            ),
          ),
        );
      },
    );
  }
}
