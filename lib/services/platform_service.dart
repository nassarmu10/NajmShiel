// lib/services/platform_service.dart
import 'platform_service_stub.dart'
    if (dart.library.html) 'platform_service_web.dart'
    if (dart.library.io) 'platform_service_mobile.dart';