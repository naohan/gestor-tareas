/// Configuración de integraciones externas.
///
/// Por defecto TODO está vacío => la app funciona 100% offline (local-first).
/// Para activar cuentas de usuario y sincronización con el backend (MySQL),
/// pasa la URL de la API con --dart-define al ejecutar/compilar:
///
///   flutter run --dart-define=API_URL=http://localhost:3000 \
///               --dart-define=GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com
///
/// Nada de esto se hardcodea en el repo (no se suben secretos).
class AppConfig {
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: '');

  static const googleClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '');
  static const googleClientSecret =
      String.fromEnvironment('GOOGLE_CLIENT_SECRET', defaultValue: '');

  /// ¿Hay backend configurado? Si no, no hay cuentas y todo se guarda local.
  static bool get usaApi => apiUrl.isNotEmpty;

  /// ¿Está configurada la integración con Google Calendar?
  static bool get usaGoogleCalendar => googleClientId.isNotEmpty;

  /// Ventana horaria laboral por defecto para planificar (24h).
  static const int horaInicioJornada = 9; // 09:00
  static const int horaFinJornada = 18; // 18:00

  /// Duración máxima de un bloque de enfoque continuo (minutos).
  static const int maxMinutosPorBloque = 90;

  /// Descanso mínimo entre bloques (minutos).
  static const int minutosDescanso = 15;

  /// Ningún bloque de enfoque dura menos que esto (minutos): ni se usan
  /// huecos más cortos ni se agendan restos menores de una tarea.
  static const int minMinutosPorBloque = 25;
}
