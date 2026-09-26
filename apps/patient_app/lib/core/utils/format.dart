import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get localeName => Localizations.localeOf(this).toLanguageTag();
}

String _loc(BuildContext c) {
  final code = Localizations.localeOf(c).languageCode;
  return DateFormat.localeExists(code) ? code : 'en';
}

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

String money(num amount) => _inr.format(amount);

String fmtDate(BuildContext c, DateTime d) => DateFormat.yMMMd(_loc(c)).format(d);

String fmtTime(BuildContext c, DateTime d) => DateFormat.jm(_loc(c)).format(d);

String fmtDateTime(BuildContext c, DateTime d) => '${fmtDate(c, d)} · ${fmtTime(c, d)}';

String fmtWeekday(BuildContext c, DateTime d) => DateFormat.E(_loc(c)).format(d);

String fmtDayMonth(BuildContext c, DateTime d) => DateFormat.MMMd(_loc(c)).format(d);

/// Parses a `YYYY-MM-DD` and formats it for display; returns input on failure.
String fmtYmd(BuildContext c, String? ymd) {
  if (ymd == null || ymd.isEmpty) return '';
  final d = DateTime.tryParse(ymd);
  return d == null ? ymd : fmtDate(c, d);
}

String fmtNumber(BuildContext c, String v) {
  final n = num.tryParse(v);
  if (n == null) return v;
  return NumberFormat.decimalPattern('en_IN').format(n);
}

String fmtBytes(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String humanize(String code) {
  if (code.isEmpty) return code;
  final s = code.replaceAll('_', ' ').toLowerCase();
  return s[0].toUpperCase() + s.substring(1);
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

String mimeFromName(String name) {
  final ext = name.split('.').last.toLowerCase();
  switch (ext) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    default:
      return 'application/octet-stream';
  }
}
