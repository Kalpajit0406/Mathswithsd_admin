import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// LaTeX math rendering widget using WebView with MathJax and dynamic height calculation
class LaTeXWidget extends StatelessWidget {
  final String text;
  final double? height;
  final TextAlign? textAlign;

  const LaTeXWidget({
    super.key,
    required this.text,
    this.height,
    this.textAlign,
  });

  bool get _hasMath {
    return text.contains(r'$') ||
        text.contains(r'\(') ||
        text.contains(r'\[') ||
        text.contains(r'$$') ||
        text.contains('\\');
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasMath) {
      return Text(
        text,
        textAlign: textAlign,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF1A1A2E),
          height: 1.4,
        ),
      );
    }
    return _WebViewLaTeXRenderer(
      text: text,
      height: height,
      textAlign: textAlign,
    );
  }
}

class _WebViewLaTeXRenderer extends StatefulWidget {
  final String text;
  final double? height;
  final TextAlign? textAlign;

  const _WebViewLaTeXRenderer({
    required this.text,
    this.height,
    this.textAlign,
  });

  @override
  State<_WebViewLaTeXRenderer> createState() => _WebViewLaTeXRendererState();
}

class _WebViewLaTeXRendererState extends State<_WebViewLaTeXRenderer> {
  late WebViewController _controller;
  bool _isLoaded = false;
  double _contentHeight = 45.0; // Start with compact default height

  static const String _baseHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <script>
    window.MathJax = {
      tex: {
        inlineMath: [['\$', '\$'], ['\\\\(', '\\\\)']],
        displayMath: [['\$\$', '\$\$'], ['\\\\[', '\\\\]']],
        processEscapes: true
      },
      options: {
        ignoreHtmlClass: 'tex2jax_ignore',
        processHtmlClass: 'tex2jax_process'
      },
      startup: {
        pageReady: () => {
          return MathJax.startup.defaultPageReady().then(() => {
            sendHeight();
          });
        }
      }
    };
  </script>
  <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
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
    .MathJax { font-size: 1.05em !important; }
  </style>
  <script>
    function sendHeight() {
      if (window.HeightChannel) {
        var height = document.body.scrollHeight || document.documentElement.scrollHeight;
        window.HeightChannel.postMessage(height.toString());
      }
    }
    function renderContent(text) {
      var el = document.getElementById('content');
      el.innerHTML = text;
      el.style.visibility = 'visible';
      if (window.MathJax && window.MathJax.typesetPromise) {
        MathJax.typesetPromise([el]).then(() => {
          sendHeight();
        });
      } else {
        setTimeout(function(){ renderContent(text); }, 80);
      }
    }
  </script>
</head>
<body>
  <div id="content" class="tex2jax_process"></div>
</body>
</html>
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'HeightChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final height = double.tryParse(message.message);
          if (height != null && mounted) {
            setState(() {
              _contentHeight = height + 12; // Add a small buffer
            });
          }
        },
      )
      ..loadHtmlString(_baseHtml)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (!mounted) return;
          _updateContent();
          setState(() => _isLoaded = true);
        },
      ));
  }

  @override
  void didUpdateWidget(covariant _WebViewLaTeXRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && _isLoaded) {
      _updateContent();
    }
  }

  void _updateContent() {
    final encoded = jsonEncode(widget.text.replaceAll('\r', ''));
    _controller.runJavaScript('renderContent($encoded);');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height ?? _contentHeight,
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

  bool get _hasMath => text.contains(r'$') || text.contains(r'\(') || text.contains(r'\[') || text.contains('\\');

  @override
  Widget build(BuildContext context) {
    if (_hasMath) {
      return LaTeXWidget(text: text);
    }
    return Text(
      text,
      style: TextStyle(fontSize: fontSize, color: color ?? const Color(0xFF1A1A2E)),
    );
  }
}
