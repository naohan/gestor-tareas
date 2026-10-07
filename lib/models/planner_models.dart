import 'task.dart';

/// Un hueco libre en la agenda, candidato a recibir trabajo enfocado.
class FreeSlot {
  final DateTime inicio;
  final DateTime fin;

  const FreeSlot(this.inicio, this.fin);

  Duration get duracion => fin.difference(inicio);

  FreeSlot copyWith({DateTime? inicio, DateTime? fin}) =>
      FreeSlot(inicio ?? this.inicio, fin ?? this.fin);

  @override
  String toString() => 'FreeSlot($inicio → $fin)';
}

/// Un bloque de enfoque planificado: a qué tarea pertenece y cuándo.
class PlannedBlock {
  final Task task;
  final DateTime inicio;
  final DateTime fin;

  const PlannedBlock({
    required this.task,
    required this.inicio,
    required this.fin,
  });

  Duration get duracion => fin.difference(inicio);

  @override
  String toString() =>
      'PlannedBlock(${task.titulo}: $inicio → $fin)';
}
