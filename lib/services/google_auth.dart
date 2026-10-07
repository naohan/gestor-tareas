import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;

/// Helpers para construir un cliente HTTP autenticado contra las APIs de
/// Google a partir de un token OAuth ya obtenido.
///
/// Foco no incrusta el flujo de consentimiento (varía mucho por plataforma).
/// La forma recomendada es delegar el login en Supabase Auth con el provider
/// Google (scope de calendar) y leer el `providerToken` de la sesión; ese
/// token se pasa aquí.
class GoogleAuth {
  static const calendarScope = 'https://www.googleapis.com/auth/calendar';

  /// Crea un cliente autenticado a partir de un access token.
  ///
  /// Si dispones de refresh token + datos de cliente, usa
  /// [authenticatedClientConRefresh] para refresco automático.
  static http.Client clientDesdeAccessToken(
    String accessToken, {
    DateTime? expira,
  }) {
    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        accessToken,
        (expira ?? DateTime.now().add(const Duration(hours: 1))).toUtc(),
      ),
      null, // sin refresh token
      const [calendarScope],
    );
    return authenticatedClient(http.Client(), credentials);
  }
}
