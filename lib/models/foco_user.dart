/// Usuario autenticado contra el backend.
class FocoUser {
  final String id;
  final String nombre;
  final String email;
  final String? avatarUrl;

  const FocoUser({
    required this.id,
    required this.nombre,
    required this.email,
    this.avatarUrl,
  });

  String get iniciales {
    final partes =
        nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letras = partes.take(2).map((p) => p[0].toUpperCase()).join();
    return letras.isEmpty ? '?' : letras;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'email': email,
        'avatarUrl': avatarUrl,
      };

  factory FocoUser.fromJson(Map<String, dynamic> json) => FocoUser(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatarUrl'] as String?,
      );
}
