import 'package:flutter/material.dart';

import '../../core/priority_engine.dart';
import '../../models/task.dart';
import '../../theme.dart';

/// Los tres ejes con los que se describe una tarea.
enum Eje { impacto, urgencia, ansiedad }

extension EjeX on Eje {
  String get label => switch (this) {
        Eje.impacto => 'Impacto',
        Eje.urgencia => 'Urgencia',
        Eje.ansiedad => 'Ansiedad',
      };

  String get pregunta => switch (this) {
        Eje.impacto => '¿Cuánto cambia si haces esta tarea?',
        Eje.urgencia => '¿Qué tan pronto necesitas hacerla?',
        Eje.ansiedad => '¿Cuánto te bloquea emocionalmente?',
      };

  IconData get icon => switch (this) {
        Eje.impacto => Icons.bolt_outlined,
        Eje.urgencia => Icons.schedule_outlined,
        Eje.ansiedad => Icons.psychology_outlined,
      };

  Color get color => switch (this) {
        Eje.impacto => FocoTheme.seed,
        Eje.urgencia => const Color(0xFFE3A94F),
        Eje.ansiedad => FocoTheme.peligro,
      };

  /// Nombre de cada nivel, de 1 a 5.
  List<String> get niveles => switch (this) {
        Eje.impacto => const ['Mínimo', 'Bajo', 'Medio', 'Alto', 'Muy alto'],
        Eje.urgencia => const [
            'Puede esperar',
            'Poco urgente',
            'Normal',
            'Urgente',
            'Muy urgente'
          ],
        Eje.ansiedad => const [
            'Tranquila',
            'Leve',
            'Me inquieta',
            'Me pesa',
            'Me está bloqueando'
          ],
      };

  String nivel(int valor) =>
      niveles[valor.clamp(Task.ejeMin, Task.ejeMax) - Task.ejeMin];
}

extension PriorityLevelUi on PriorityLevel {
  Color get color => switch (this) {
        PriorityLevel.muyAlta => FocoTheme.peligro,
        PriorityLevel.alta => const Color(0xFFE3A94F),
        PriorityLevel.media => FocoTheme.seed,
        PriorityLevel.baja => FocoTheme.acento,
      };

  IconData get icon => switch (this) {
        PriorityLevel.muyAlta => Icons.local_fire_department,
        PriorityLevel.alta => Icons.trending_up,
        PriorityLevel.media => Icons.balance_outlined,
        PriorityLevel.baja => Icons.spa_outlined,
      };
}

/// "15 min", "1 h", "1 h 30 min"...
String formatHoras(double horas) {
  final minutos = (horas * 60).round();
  final h = minutos ~/ 60;
  final m = minutos % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

/// Tarjeta con la prioridad calculada por el motor (no la elige el usuario).
class PrioridadCard extends StatelessWidget {
  final PriorityLevel nivel;
  final bool compacta;

  const PrioridadCard({super.key, required this.nivel, this.compacta = false});

  @override
  Widget build(BuildContext context) {
    final color = nivel.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.all(compacta ? 14 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.28), FocoTheme.superficie2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: compacta ? 40 : 52,
            height: compacta ? 40 : 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(nivel.icon, color: color, size: compacta ? 22 : 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prioridad calculada',
                    style: TextStyle(fontSize: 12, color: Colors.white60)),
                Text(nivel.label.toUpperCase(),
                    style: TextStyle(
                        fontSize: compacta ? 18 : 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: color)),
                if (!compacta) ...[
                  const SizedBox(height: 2),
                  Text(nivel.mensaje,
                      style: const TextStyle(color: Colors.white70)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta pequeña con color, p. ej. el nivel de un eje.
class NivelBadge extends StatelessWidget {
  final String texto;
  final Color color;
  const NivelBadge({super.key, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
