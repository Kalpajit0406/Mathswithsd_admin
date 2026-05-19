import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// KaTeX math rendering widget using WebView
class KaTeXWidget extends StatefulWidget {
  final String text;
  final double? height;
  final TextAlign? textAlign;

  const KaTeXWidget({
    super.key,
    required this.text,
    this.height,
    this.textAlign,
  });

  @override
  State<KaTeXWidget> createState() => _KaTeXWidgetState();
}

class _KaTeXWidgetState extends State<KaTeXWidget> {
  late WebViewController _controller;
  bool _isLoaded = false;

  static const String _baseHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.css">
  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.js"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/contrib/auto-render.min.js"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, 'Segoe UI', sans-serif;
      font-size: 15px;
      color: #1A1A2E;
      padding: 4px;
      word-wrap: break-word;
      overflow-wrap: break-word;
    }
    #content { visibility: hidden; line-height: 1.6; }
    .katex { font-size: 1em; }
    .katex-display { overflow-x: auto; overflow-y: hidden; }
  </style>
  <script>
    function renderContent(text) {
      var el = document.getElementById('content');
      el.innerHTML = text;
      if (window.renderMathInElement) {
        renderMathInElement(el, {
          delimiters: [
            {left: '\$\$', right: '\$\$', display: true},
            {left: '\$', right: '\$', display: false},
            {left: '\\\\(', right: '\\\\)', display: false},
            {left: '\\\\[', right: '\\\\]', display: true}
          ],
          throwOnError: false
        });
        el.style.visibility = 'visible';
        window.flutter_inappwebview && window.flutter_inappwebview.callHandler('heightChanged', document.body.scrollHeight);
      } else {
        setTimeout(function(){ renderContent(text); }, 80);
      }
    }
  </script>
</head>
<body>
  <div id="content"></div>
</body>
</html>
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadHtmlString(_baseHtml)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _updateContent();
          setState(() => _isLoaded = true);
        },
      ));
  }

  @override
  void didUpdateWidget(covariant KaTeXWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && _isLoaded) {
      _updateContent();
    }
  }

  void _updateContent() {
    final escaped = widget.text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
    _controller.runJavaScript("renderContent('$escaped');");
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height ?? 80,
      child: WebViewWidget(controller: _controller),
    );
  }
}

/// Inline math text — use for option rendering in exams
class InlineMathText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color? color;

  const InlineMathText({
    super.key,
    required this.text,
    this.fontSize = 15,
    this.color,
  });

  bool get _hasMath => text.contains(r'$') || text.contains(r'\(') || text.contains(r'\[');

  @override
  Widget build(BuildContext context) {
    if (_hasMath) {
      return KaTeXWidget(text: text, height: 50);
    }
    return Text(
      text,
      style: TextStyle(fontSize: fontSize, color: color ?? const Color(0xFF1A1A2E)),
    );
  }
}
