import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      // Riverpod 3 retries failing providers by default; our screens show an
      // explicit error + retry instead.
      retry: (retryCount, error) => null,
      child: const DoctorApp(),
    ),
  );
}
