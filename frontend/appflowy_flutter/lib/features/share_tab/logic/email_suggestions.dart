class EmailSuggestions {
  EmailSuggestions({this.defaultDomains = _defaultDomains})
      : assert(defaultDomains.isNotEmpty);

  final List<String> defaultDomains;

  List<String> generateEmails(String input) {
    /// if there is no '@', return a suggestion list(eg: "xxx")
    if (!input.contains('@')) {
      return defaultDomains.map((e) => '$input$e').toList();
    }

    /// divide the input into local part and domain part
    final parts = input.split('@');
    final localPart = parts[0];
    final domainPart = parts.sublist(1).join('@');

    if (parts.length > 2) return [input];

    /// handle the case where there is no domain part(eg: "xxx@")
    if (domainPart.isEmpty) {
      return defaultDomains.map((e) => '$localPart$e').toList();
    }

    final domain = domainPart.toLowerCase();

    final List<String> suggestions = [];
    for (final fullDomain in defaultDomains) {
      if (fullDomain.startsWith('@$domain')) {
        suggestions.add('$localPart$fullDomain');
      }
    }

    if (suggestions.isNotEmpty) return suggestions;

    return [input];
  }
}

const _defaultDomains = [
  '@gmail.com',
  '@yahoo.com',
  '@outlook.com',
];
