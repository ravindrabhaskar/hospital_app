// Platform helpers with conditional implementations (IO vs web).
export 'platform_files_stub.dart'
    if (dart.library.io) 'platform_files_io.dart'
    if (dart.library.js_interop) 'platform_files_web.dart';
