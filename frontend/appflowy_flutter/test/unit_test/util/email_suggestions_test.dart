import 'package:appflowy/features/share_tab/logic/email_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final emailSuggestions = EmailSuggestions();
  test('test for email suggestions', () {
    expect(
      emailSuggestions.generateEmails('xxx'),
      emailSuggestions.defaultDomains.map((e) => 'xxx$e').toList(),
    );

    expect(
      emailSuggestions.generateEmails('xxx@'),
      emailSuggestions.defaultDomains.map((e) => 'xxx$e').toList(),
    );

    expect(
      emailSuggestions.generateEmails('xxx@gm'),
      ['xxx@gmail.com'],
    );

    expect(
      emailSuggestions.generateEmails('xxx@GM'),
      ['xxx@gmail.com'],
    );

    expect(
      emailSuggestions.generateEmails('xxx@gmail.c'),
      ['xxx@gmail.com'],
    );

    expect(
      emailSuggestions.generateEmails('xxx@ya'),
      ['xxx@yahoo.com'],
    );

    expect(
      emailSuggestions.generateEmails('xxx@yahoo.co'),
      ['xxx@yahoo.com'],
    );

    expect(
      emailSuggestions.generateEmails('xxx@ou'),
      ['xxx@outlook.com'],
    );

    expect(
      emailSuggestions.generateEmails('xxx@gx'),
      ['xxx@gx'],
    );

    expect(
      emailSuggestions.generateEmails('example@hotmail.com'),
      ['example@hotmail.com'],
    );

    expect(
      emailSuggestions.generateEmails('@@'),
      ['@@'],
    );

    expect(
      emailSuggestions.generateEmails('a@ .com'),
      ['a@ .com'],
    );

    expect(
      emailSuggestions.generateEmails('a@@'),
      ['a@@'],
    );
  });
}
