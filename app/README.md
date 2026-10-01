# accent

Remote for server-side AI infrastructure

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Languages

The UI is translated with Flutter's gen-l10n. Every user-visible string lives in `lib/l10n/`, one ARB file per language (`app_en.arb` is the template, `app_ru.arb` the Russian copy). The language menu on the servers screen lists every language that has a file, plus System.

To add a language:

1. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<code>.arb` (e.g. `app_de.arb`), set `"@@locale"` to the code, and translate every value — keep the keys and `{placeholders}` unchanged; `@`-metadata entries can be dropped.
2. Run `flutter gen-l10n` (also run implicitly by `flutter pub get`) and commit the regenerated `lib/l10n/app_localizations*.dart`.
3. `flutter test` — `test/l10n_test.dart` checks the English and Russian files carry the same keys.
