import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/common.dart';
import 'format.dart';

/// Opens [uri] outside the app; shows a snack if nothing can handle it.
Future<bool> openExternal(BuildContext context, Uri uri) async {
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) showSnack(context, context.l10n.couldNotOpenLink, error: true);
  return ok;
}

String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

Uri telUri(String phone) => Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));

Uri whatsappUri(String phone) => Uri.parse('https://wa.me/${_digits(phone)}');

Uri mailUri(String email, {String? subject}) =>
    Uri(scheme: 'mailto', path: email, query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}');
