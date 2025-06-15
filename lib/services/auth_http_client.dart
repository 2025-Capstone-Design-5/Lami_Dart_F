import 'package:http/http.dart' as http;
import '../providers/auth_state.dart';
import 'auth_service.dart';

/// HTTP client that logs out on 401 responses.
class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner;
  final AuthState authState;

  AuthenticatedClient(this._inner, this.authState);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (response.statusCode == 401) {
      // Clear local credentials and update auth state
      await AuthService().logout();
      authState.setLoggedIn(false);
    }
    return response;
  }
} 