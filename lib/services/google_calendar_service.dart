import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;

import '../models/calendar_event.dart';
import 'calendar_service.dart';

/// Integración real con Google Calendar vía la API REST (paquete googleapis).
///
/// Recibe un [http.Client] YA autenticado (con un token OAuth válido y el
/// scope `https://www.googleapis.com/auth/calendar`). La obtención del token
/// se resuelve fuera (ver README): puede venir del login con Google de
/// Supabase (provider token) o de un flujo OAuth nativo.
class GoogleCalendarService implements CalendarService {
  final http.Client _httpClient;
  final String email;
  final String calendarId;

  late final gcal.CalendarApi _api = gcal.CalendarApi(_httpClient);

  GoogleCalendarService(
    this._httpClient, {
    required this.email,
    this.calendarId = 'primary',
  });

  @override
  bool get conectado => true;

  @override
  String? get cuenta => email;

  @override
  Future<List<CalendarEvent>> ocupaciones(
      DateTime desde, DateTime hasta) async {
    final res = await _api.events.list(
      calendarId,
      timeMin: desde.toUtc(),
      timeMax: hasta.toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
    );

    final eventos = <CalendarEvent>[];
    for (final e in res.items ?? const <gcal.Event>[]) {
      final inicio = e.start?.dateTime?.toLocal();
      final fin = e.end?.dateTime?.toLocal();
      if (inicio == null || fin == null) continue; // ignora eventos de día completo
      // 'transparent' = disponible; cualquier otra cosa cuenta como ocupado.
      final ocupado = (e.transparency ?? 'opaque') != 'transparent';
      eventos.add(CalendarEvent(
        id: e.id ?? '${inicio.millisecondsSinceEpoch}',
        googleEventId: e.id,
        titulo: e.summary ?? '(sin título)',
        inicio: inicio,
        fin: fin,
        source: EventSource.googleSync,
        ocupado: ocupado,
      ));
    }
    return eventos;
  }

  @override
  Future<CalendarEvent> crearEvento(CalendarEvent evento) async {
    final gevent = gcal.Event(
      summary: evento.titulo,
      start: gcal.EventDateTime(dateTime: evento.inicio.toUtc()),
      end: gcal.EventDateTime(dateTime: evento.fin.toUtc()),
      extendedProperties: gcal.EventExtendedProperties(private: {
        'foco_task_id': evento.taskId ?? '',
        'foco_source': evento.source.wire,
      }),
    );

    final creado = await _api.events.insert(gevent, calendarId);
    return CalendarEvent(
      id: evento.id,
      googleEventId: creado.id,
      taskId: evento.taskId,
      titulo: evento.titulo,
      inicio: evento.inicio,
      fin: evento.fin,
      source: evento.source,
      ocupado: evento.ocupado,
    );
  }
}
