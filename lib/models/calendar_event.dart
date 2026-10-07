/// Origen de un evento de calendario.
enum EventSource {
  /// Leído desde Google Calendar (ocupación existente).
  googleSync,

  /// Bloque de enfoque propuesto/escrito por Foco.
  focoPlanned,
}

extension EventSourceX on EventSource {
  String get wire => this == EventSource.googleSync ? 'google_sync' : 'foco_planned';

  static EventSource fromWire(String? s) =>
      s == 'foco_planned' ? EventSource.focoPlanned : EventSource.googleSync;
}

/// Evento de calendario. Una sola entidad para dos usos diferenciados por
/// [source]: ocupaciones leídas de Google y bloques de enfoque de Foco.
class CalendarEvent {
  final String id;
  final String? googleEventId;
  final String? taskId;
  String titulo;
  DateTime inicio;
  DateTime fin;
  EventSource source;
  bool ocupado;

  CalendarEvent({
    required this.id,
    this.googleEventId,
    this.taskId,
    required this.titulo,
    required this.inicio,
    required this.fin,
    this.source = EventSource.googleSync,
    this.ocupado = true,
  });

  Duration get duracion => fin.difference(inicio);

  Map<String, dynamic> toJson() => {
        'id': id,
        'googleEventId': googleEventId,
        'taskId': taskId,
        'titulo': titulo,
        'inicio': inicio.toIso8601String(),
        'fin': fin.toIso8601String(),
        'source': source.wire,
        'ocupado': ocupado,
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'] as String,
        googleEventId: json['googleEventId'] as String?,
        taskId: json['taskId'] as String?,
        titulo: json['titulo'] as String,
        inicio: DateTime.parse(json['inicio'] as String),
        fin: DateTime.parse(json['fin'] as String),
        source: EventSourceX.fromWire(json['source'] as String?),
        ocupado: (json['ocupado'] as bool?) ?? true,
      );
}
