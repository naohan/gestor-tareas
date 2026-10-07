import 'package:flutter/material.dart';

/// Estado del ciclo de vida de una tarea.
enum TaskStatus { pendiente, enProgreso, completada }

extension TaskStatusX on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.pendiente:
        return 'Pendiente';
      case TaskStatus.enProgreso:
        return 'En progreso';
      case TaskStatus.completada:
        return 'Completada';
    }
  }
}

/// Categoría temática de la tarea. La app no obliga a clasificar todo,
/// pero ayuda a equilibrar la carga entre áreas de la vida.
enum TaskCategory { trabajo, estudio, personal, salud, proyecto }

extension TaskCategoryX on TaskCategory {
  String get label {
    switch (this) {
      case TaskCategory.trabajo:
        return 'Trabajo';
      case TaskCategory.estudio:
        return 'Estudio';
      case TaskCategory.personal:
        return 'Personal';
      case TaskCategory.salud:
        return 'Salud';
      case TaskCategory.proyecto:
        return 'Proyecto';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskCategory.trabajo:
        return Icons.work_outline;
      case TaskCategory.estudio:
        return Icons.school_outlined;
      case TaskCategory.personal:
        return Icons.self_improvement_outlined;
      case TaskCategory.salud:
        return Icons.favorite_outline;
      case TaskCategory.proyecto:
        return Icons.rocket_launch_outlined;
    }
  }

  Color get color {
    switch (this) {
      case TaskCategory.trabajo:
        return const Color(0xFF5B8DEF);
      case TaskCategory.estudio:
        return const Color(0xFF9B6DE3);
      case TaskCategory.personal:
        return const Color(0xFF4FB286);
      case TaskCategory.salud:
        return const Color(0xFFE36D8B);
      case TaskCategory.proyecto:
        return const Color(0xFFE3A94F);
    }
  }
}

/// Una tarea NO es un simple ToDo. Lleva tres ejes que la mayoría de apps
/// ignoran: impacto, urgencia y, sobre todo, ansiedad (cuánto te bloquea
/// emocionalmente), porque tareas pequeñas pueden generar mucho bloqueo.
class Task {
  final String id;
  String titulo;
  String descripcion;
  DateTime? fechaLimite;
  double horasEstimadas;
  TaskStatus estado;
  TaskCategory categoria;

  static const int ejeMin = 1;
  static const int ejeMax = 5;

  /// Ejes de [ejeMin] a [ejeMax].
  int impacto;
  int urgencia;
  int ansiedad;

  /// IDs de tareas de las que ésta depende. Si alguna no está completada,
  /// esta tarea se considera "bloqueada" (no debería iniciarse aún).
  List<String> dependencias;

  /// Si el usuario la marcó como uno de los pocos objetivos activos.
  bool activa;

  DateTime creada;
  DateTime? completadaEn;

  Task({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    this.fechaLimite,
    this.horasEstimadas = 1,
    this.estado = TaskStatus.pendiente,
    this.categoria = TaskCategory.proyecto,
    this.impacto = 3,
    this.urgencia = 3,
    this.ansiedad = 3,
    List<String>? dependencias,
    this.activa = false,
    DateTime? creada,
    this.completadaEn,
  })  : dependencias = dependencias ?? <String>[],
        creada = creada ?? DateTime.now();

  bool get completada => estado == TaskStatus.completada;

  /// Días hasta la fecha límite (negativo si ya venció). null si no tiene.
  int? get diasRestantes {
    if (fechaLimite == null) return null;
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final limite =
        DateTime(fechaLimite!.year, fechaLimite!.month, fechaLimite!.day);
    return limite.difference(hoy).inDays;
  }

  bool get vencida {
    final d = diasRestantes;
    return d != null && d < 0 && !completada;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'descripcion': descripcion,
        'fechaLimite': fechaLimite?.toIso8601String(),
        'horasEstimadas': horasEstimadas,
        'estado': estado.name,
        'categoria': categoria.name,
        'impacto': impacto,
        'urgencia': urgencia,
        'ansiedad': ansiedad,
        'dependencias': dependencias,
        'activa': activa,
        'creada': creada.toIso8601String(),
        'completadaEn': completadaEn?.toIso8601String(),
      };

  static int _eje(Object? v) =>
      ((v as num?)?.toInt() ?? 3).clamp(ejeMin, ejeMax);

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        titulo: json['titulo'] as String,
        descripcion: (json['descripcion'] as String?) ?? '',
        fechaLimite: json['fechaLimite'] != null
            ? DateTime.parse(json['fechaLimite'] as String)
            : null,
        horasEstimadas: (json['horasEstimadas'] as num?)?.toDouble() ?? 1,
        estado: TaskStatus.values
            .firstWhere((e) => e.name == json['estado'], orElse: () => TaskStatus.pendiente),
        categoria: TaskCategory.values.firstWhere(
            (e) => e.name == json['categoria'],
            orElse: () => TaskCategory.proyecto),
        impacto: _eje(json['impacto']),
        urgencia: _eje(json['urgencia']),
        ansiedad: _eje(json['ansiedad']),
        dependencias: (json['dependencias'] as List?)?.cast<String>() ?? <String>[],
        activa: (json['activa'] as bool?) ?? false,
        creada: json['creada'] != null
            ? DateTime.parse(json['creada'] as String)
            : DateTime.now(),
        completadaEn: json['completadaEn'] != null
            ? DateTime.parse(json['completadaEn'] as String)
            : null,
      );

  Task copyWith({
    String? titulo,
    String? descripcion,
    DateTime? fechaLimite,
    bool clearFechaLimite = false,
    double? horasEstimadas,
    TaskStatus? estado,
    TaskCategory? categoria,
    int? impacto,
    int? urgencia,
    int? ansiedad,
    List<String>? dependencias,
    bool? activa,
    DateTime? completadaEn,
  }) {
    return Task(
      id: id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      fechaLimite: clearFechaLimite ? null : (fechaLimite ?? this.fechaLimite),
      horasEstimadas: horasEstimadas ?? this.horasEstimadas,
      estado: estado ?? this.estado,
      categoria: categoria ?? this.categoria,
      impacto: impacto ?? this.impacto,
      urgencia: urgencia ?? this.urgencia,
      ansiedad: ansiedad ?? this.ansiedad,
      dependencias: dependencias ?? this.dependencias,
      activa: activa ?? this.activa,
      creada: creada,
      completadaEn: completadaEn ?? this.completadaEn,
    );
  }
}
