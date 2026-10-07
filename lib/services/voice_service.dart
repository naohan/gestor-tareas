import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Dictado en español con el reconocedor de voz del sistema (o del navegador
/// en web). Solo transcribe; interpretar la frase es cosa de VoiceTaskParser.
class VoiceService extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();

  bool _inicializado = false;
  bool _disponible = false;
  String? _localeId;
  bool _disposed = false;

  bool get disponible => _disponible;

  bool _escuchando = false;
  bool get escuchando => _escuchando;

  String _transcripcion = '';
  String get transcripcion => _transcripcion;

  String? _error;
  String? get error => _error;

  /// Se llama con la transcripción al terminar de escuchar.
  ValueChanged<String>? onFinal;

  Future<bool> inicializar() async {
    if (_inicializado) return _disponible;
    _inicializado = true;
    try {
      _disponible = await _stt.initialize(
        onError: _alError,
        onStatus: _alCambiarEstado,
      );
      if (_disponible) _localeId = await _elegirIdioma();
    } catch (_) {
      _disponible = false;
    }
    if (!_disponible) {
      _error = 'El dictado por voz no está disponible en este dispositivo. '
          'Puedes escribir la frase.';
    }
    _notificar();
    return _disponible;
  }

  Future<String> _elegirIdioma() async {
    bool esEspanol(String id) => id.toLowerCase().startsWith('es');
    try {
      final sistema = await _stt.systemLocale();
      if (sistema != null && esEspanol(sistema.localeId)) {
        return sistema.localeId;
      }
      final locales = await _stt.locales();
      for (final l in locales) {
        if (esEspanol(l.localeId)) return l.localeId;
      }
    } catch (_) {}
    return 'es-ES';
  }

  Future<void> escuchar() async {
    if (!await inicializar() || _escuchando) return;
    // SpeechToText es un singleton que solo registra listeners en su primer
    // initialize; se reasignan para que los eventos lleguen a esta instancia.
    _stt.errorListener = _alError;
    _stt.statusListener = _alCambiarEstado;
    _transcripcion = '';
    _error = null;
    _escuchando = true;
    _notificar();
    try {
      await _stt.listen(
        onResult: (r) {
          _transcripcion = r.recognizedWords;
          _notificar();
        },
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      _escuchando = false;
      _error = 'No se pudo usar el micrófono.';
      _notificar();
    }
  }

  Future<void> detener() async {
    if (!_escuchando) return;
    await _stt.stop();
  }

  void _alCambiarEstado(String estado) {
    final termino = estado == SpeechToText.doneStatus ||
        estado == SpeechToText.notListeningStatus;
    if (termino && _escuchando) {
      _escuchando = false;
      _notificar();
      if (_transcripcion.trim().isNotEmpty) onFinal?.call(_transcripcion);
    }
  }

  void _alError(SpeechRecognitionError e) {
    _escuchando = false;
    _error = _mensaje(e.errorMsg);
    _notificar();
  }

  static String _mensaje(String codigo) {
    switch (codigo) {
      case 'error_no_match':
      case 'error_speech_timeout':
      case 'no-speech':
        return 'No te escuché bien. Toca el micrófono e inténtalo otra vez.';
      case 'error_permission':
      case 'not-allowed':
      case 'service-not-allowed':
        return 'Necesito permiso para usar el micrófono.';
      case 'network':
        // En web el navegador transcribe con su propio servicio en la nube;
        // los navegadores embebidos o sin ese servicio devuelven este error.
        return 'Este navegador no puede usar su servicio de dictado. '
            'Abre Foco en Chrome o Edge, o escribe la frase aquí abajo.';
      case 'error_network':
      case 'error_network_timeout':
        return 'El reconocimiento de voz necesita conexión a internet.';
      case 'audio-capture':
      case 'error_audio':
        return 'No encuentro un micrófono.';
      default:
        return 'Hubo un problema con el dictado ($codigo).';
    }
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_escuchando) _stt.cancel();
    if (_stt.errorListener == _alError) _stt.errorListener = null;
    if (_stt.statusListener == _alCambiarEstado) _stt.statusListener = null;
    super.dispose();
  }
}
