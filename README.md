# Month Ledger — Android preview

A manual-entry budgeting app built with Flutter. The first launch is a blank budget with starter categories; the preview images show example amounts only.

## Install

Copy **Month-Ledger.apk** to your Android phone, open it, and allow installation from the app you used to open the file if Android asks. Requires Android 7.0 or later. This is a personally installable preview, not a Play Store release. Keep the installer if you want to reinstall it.

## Use

- **Overview** opens to the current month. Planned and actual amounts are read-only here. Scroll vertically to see more categories, or horizontally to see Difference. Headings stay above the figures and category names remain on the left.
- **Plan** lets you change amounts for the chosen month, add income or expense categories, or copy the prior month. New categories appear across all months, starting at zero.
- **Entries** records actual income or spending. Choose the category, amount and date. Tap a saved entry to edit it, or use its menu to delete it.
- **Year** shows planned and actual income, expenses, and gain or loss for all twelve months and the full selected year.
- Use the month arrows, tap the month title to choose another date, or tap the calendar at top right to return to the current month.
- The navigation menu includes **Backup & help**. Save a backup periodically and before uninstalling. Restoring a backup replaces all existing data after confirmation.

Planned gain or loss = planned income − planned expenses. Actual gain or loss = entered income − entered expenses. Difference is favorable when positive: actual income above plan or actual spending below plan. Amounts use dollars with two decimal places. Savings is an outgoing category, so it reduces the planned gain. All months begin at zero; plans do not roll forward automatically.

## Storage and current limits

Data saves locally after every edit; no account, server, bank connection, or network permission is required. Backups use Android's file chooser and can be saved wherever you choose. Backup JSON files are not encrypted. Uninstalling or clearing app storage removes local data. There is no automatic cloud sync.

This preview accepts positive transaction amounts; income/expense direction comes from the category. Refunds, transfers between accounts, multiple currencies, recurring entries, category renaming/removal, and bank import are future additions. Categories and transactions have stable IDs, and planned amounts are separate from transactions to support later import work.

The interface and data model can be reused for iPhone. iPhone platform storage and file-picker integration still needs implementation and testing.

## Development

Open this folder as a Flutter project. Use Flutter 3.47.2 / Dart 3.13.2, JDK 21, Android SDK 36, Build Tools 36.0.0 and NDK 28.2.13676358. The Android build uses Gradle 8.14.3, AGP 8.11.1 and Kotlin 2.2.20.

```
flutter pub get
flutter analyze
flutter test test/budget_test.dart
flutter build apk --release
```

The prototype release uses Android's development signing configuration. Keep the same signing key when updating an existing installation; changing the key requires uninstalling, which clears app data. A separate production signing key and store configuration are needed before publishing. The native storage/file-picker bridge is in `MainActivity.kt`; budgeting and money calculations are in `lib/model.dart`.

Automated checks cover exact cent parsing, invalid input/backups, independent monthly plans, calendar-year totals, transaction entry, saving/reopening, and frozen table headings. These tests mock the Android storage bridge; they do not replace on-device testing of installation and Android file pickers.

See [Flutter's Android deployment guide](https://docs.flutter.dev/deployment/android) for release and installation details.
