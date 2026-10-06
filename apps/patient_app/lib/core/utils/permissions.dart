import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/common.dart';
import 'format.dart';

/// Which permission a picker failure was caused by.
enum PickerDenial { camera, photos }

/// Classifies a picker error. image_picker reports a refused permission as a
/// [PlatformException] with `camera_access_denied` / `photo_access_denied`
/// (Android and iOS); anything else is a generic failure (null).
PickerDenial? pickerDenial(Object error) {
  if (error is! PlatformException) return null;
  final code = error.code.toLowerCase();
  if (!code.contains('denied') && !code.contains('permission')) return null;
  return code.contains('camera') ? PickerDenial.camera : PickerDenial.photos;
}

/// Opens this app's page in the system settings (where a permanently denied
/// permission can be turned back on). Never throws.
Future<bool> openAppSettingsPage() async {
  try {
    return await Geolocator.openAppSettings();
  } catch (_) {
    return false;
  }
}

/// Shows why a picker failed: a specific message with an "Open settings"
/// action for a refused camera/photos permission, else the generic error.
void showPickerError(BuildContext context, Object error) {
  final l = context.l10n;
  final denial = pickerDenial(error);
  if (denial == null) {
    showSnack(context, l.pickerFailed, error: true);
    return;
  }
  showSnack(
    context,
    denial == PickerDenial.camera ? l.cameraPermissionDenied : l.photosPermissionDenied,
    error: true,
    action: SnackBarAction(
      key: const Key('open-app-settings'),
      label: l.openSettings,
      textColor: Colors.white,
      onPressed: openAppSettingsPage,
    ),
  );
}
