/// Proyecto que agrupa tareas. Aún no tiene UI propia, pero el modelo y la
/// sincronización ya existen para cuando se añada esa vista.
class Project {
  final String id;
  String nombre;
  DateTime? fechaLimite;
  String estado; // activo | pausado | terminado
  DateTime creada;

  Project({
    required this.id,
    required this.nombre,
    this.fechaLimite,
    this.estado = 'activo',
    DateTime? creada,
  }) : creada = creada ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'fechaLimite': fechaLimite?.toIso8601String(),
        'estado': estado,
        'creada': creada.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        fechaLimite: json['fechaLimite'] != null
            ? DateTime.parse(json['fechaLimite'] as String)
            : null,
        estado: (json['estado'] as String?) ?? 'activo',
        creada: json['creada'] != null
            ? DateTime.parse(json['creada'] as String)
            : DateTime.now(),
      );
}
