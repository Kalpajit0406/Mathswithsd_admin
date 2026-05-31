class LatexToReadableConverter {
  static String convert(String latex) {
    if (latex.isEmpty) return '';

    String result = latex;

    // Fix raw \sqrt missing arguments to prevent parsing crash
    result = result.replaceAll(RegExp(r'\\sqrt\s*(?![\{\[\w\d\\])'), r'\sqrt{}');

    // First insert spaces around math delimiters if they are missing
    result = result.replaceAllMapped(RegExp(r'(\w)(\$\$)'), (m) => '${m[1]} ${m[2]}');
    result = result.replaceAllMapped(RegExp(r'(\$\$)(\w)'), (m) => '${m[1]} ${m[2]}');
    result = result.replaceAllMapped(RegExp(r'(\w)(?<!\\)\$(?!\$)'), (m) => '${m[1]} \$');
    result = result.replaceAllMapped(RegExp(r'(?<!\\)\$(?!\$)(\w)'), (m) => '\$ ${m[1]}');
    result = result.replaceAllMapped(RegExp(r'(\w)(\\\(|\\\[)'), (m) => '${m[1]} ${m[2]}');
    result = result.replaceAllMapped(RegExp(r'(\\\)|\\\])(\w)'), (m) => '${m[1]} ${m[2]}');

    // Remove LaTeX block equation display elements
    result = result.replaceAll(r'$$', '');
    result = result.replaceAll(RegExp(r'(?<!\\)\$'), '');

    // Clean up text environments e.g., \text{Hello} -> Hello
    result = result.replaceAllMapped(RegExp(r'\\text\{([^}]+)\}'), (m) => m[1]!);

    // Handle common fractions: \frac{a}{b} -> a/b
    // Support nested or single characters: \frac{1}{2} -> 1/2
    result = result.replaceAllMapped(
      RegExp(r'\\frac\s*\{([^}]+)\}\s*\{([^}]+)\}'),
      (match) => '${match.group(1)}/${match.group(2)}'
    );

    // Support single token fractions without braces: \frac 1 2 -> 1/2
    result = result.replaceAllMapped(
      RegExp(r'\\frac\s+([^{])\s+([^{])'),
      (match) => '${match.group(1)}/${match.group(2)}'
    );

    // Handle square roots: \sqrt{x} -> √x
    result = result.replaceAllMapped(
      RegExp(r'\\sqrt\s*\{([^}]+)\}'),
      (match) => '√(${match.group(1)})'
    );
    // \sqrt[n]{x} -> ⁿ√(x)
    result = result.replaceAllMapped(
      RegExp(r'\\sqrt\s*\[([^\]]+)\]\s*\{([^}]+)\}'),
      (match) => '(${match.group(1)})√(${match.group(2)})'
    );

    // Common Greek Letters
    final greekLetters = {
      r'\theta': 'θ',
      r'\pi': 'π',
      r'\alpha': 'α',
      r'\beta': 'β',
      r'\gamma': 'γ',
      r'\Delta': 'Δ',
      r'\sigma': 'σ',
      r'\mu': 'μ',
      r'\lambda': 'λ',
      r'\omega': 'ω',
      r'\phi': 'φ',
    };
    greekLetters.forEach((key, val) {
      result = result.replaceAll(key, val);
    });

    // Set theory & logic symbols
    final symbols = {
      r'\cup': '∪',
      r'\cap': '∩',
      r'\pm': '±',
      r'\ge': '≥',
      r'\geq': '≥',
      r'\le': '≤',
      r'\leq': '≤',
      r'\times': '×',
      r'\div': '÷',
      r'\neq': '≠',
      r'\in': '∈',
      r'\infty': '∞',
      r'\to': '→',
      r'\rightarrow': '→',
      r'\leftarrow': '←',
      r'\cdot': '·',
      r'\approx': '≈',
      r'\forall': '∀',
      r'\exists': '∃',
    };
    symbols.forEach((key, val) {
      result = result.replaceAll(key, val);
    });

    // Superscripts mapping: ^2 -> ², ^3 -> ³
    final superscripts = {
      '^0': '⁰', '^1': '¹', '^2': '²', '^3': '³', '^4': '⁴',
      '^5': '⁵', '^6': '⁶', '^7': '⁷', '^8': '⁸', '^9': '⁹',
      '^{0}': '⁰', '^{1}': '¹', '^{2}': '²', '^{3}': '³', '^{4}': '⁴',
      '^{5}': '⁵', '^{6}': '⁶', '^{7}': '⁷', '^{8}': '⁸', '^{9}': '⁹',
    };
    superscripts.forEach((key, val) {
      result = result.replaceAll(key, val);
    });

    // Subscripts mapping: _1 -> ₁
    final subscripts = {
      '_0': '₀', '_1': '₁', '_2': '₂', '_3': '₃', '_4': '₄',
      '_5': '₅', '_6': '₆', '_7': '₇', '_8': '₈', '_9': '₉',
      '_{0}': '₀', '_{1}': '₁', '_{2}': '₂', '_{3}': '₃', '_{4}': '₄',
      '_{5}': '₅', '_{6}': '₆', '_{7}': '₇', '_{8}': '₈', '_{9}': '₉',
    };
    subscripts.forEach((key, val) {
      result = result.replaceAll(key, val);
    });

    // Clean up KaTeX brackets spacing commands
    result = result.replaceAll(RegExp(r'\\[bB]ig[glr]?'), '');
    result = result.replaceAll(RegExp(r'\\left'), '');
    result = result.replaceAll(RegExp(r'\\right'), '');

    // Strip remaining escaped backslashes for commands
    result = result.replaceAllMapped(
      RegExp(r'\\([a-zA-Z]+)'),
      (match) => match.group(1)!
    );

    // Replace double spaces
    result = result.replaceAll(RegExp(r'\s+'), ' ');

    return result.trim();
  }
}
