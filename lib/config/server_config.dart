import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Returns the backend server base URL based on the current platform.
String getServerBaseUrl() {
  if (Platform.isAndroid) {
    // Android emulator uses 10.0.2.2 to reach localhost
    return dotenv.env['BACKEND_URL_ANDROID'] ?? 'http://10.0.2.2:3000';
  } else if (Platform.isIOS) {
    return dotenv.env['BACKEND_URL_IOS'] ?? (dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000');
  } else {
    return dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
  }
} 