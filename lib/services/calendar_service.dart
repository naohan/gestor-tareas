import '../models/calendar_event.dart';

/// Contrato del calendario. Permite leer ocupaciones (para detectar huecos)
/// y escribir bloques de enfoque. Implementación: GoogleCalendarService.
abstract class CalendarService {
  bool get conectado;

  /// Identificador legible de la cuenta conectada (p. ej. el email).
  String? get cuenta;

  /// Lee los eventos ocupados entre [desde] y [hasta].
  Future<List<CalendarEvent>> ocupaciones(DateTime desde, DateTime hasta);

  /// Crea un evento de enfoque en el calendario. Devuelve el evento con el
  /// id remoto asignado (si aplica).
  Future<CalendarEvent> crearEvento(CalendarEvent evento);
}
