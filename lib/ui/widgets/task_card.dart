import 'package:flutter/material.dart';

import '../../core/priority_engine.dart';
import '../../models/task.dart';
import '../../theme.dart';

/// Tarjeta de tarea. Muestra lo esencial para decidir: título, categoría,
/// días restantes, y (opcional) la razón por la que importa ahora.
class TaskCard extends StatelessWidget {
  final Task task;
  final PriorityScore? score;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onToggleActiva;
  final bool mostrarRazon;

  const TaskCard({
    super.key,
    required this.task,
    this.score,
    this.onTap,
    this.onComplete,
    this.onToggleActiva,
    this.mostrarRazon = false,
  });

  @override
  Widget build(BuildContext context) {
    final cat = task.categoria;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onComplete != null)
                _CompleteButton(
                  completada: task.completada,
                  onTap: onComplete!,
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.titulo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: task.completada
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.completada ? Colors.white38 : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Tag(
                          icon: cat.icon,
                          label: cat.label,
                          color: cat.color,
                        ),
                        _DeadlineTag(task: task),
                        if (score != null)
                          _Tag(
                            icon: Icons.bolt,
                            label: score!.total.toStringAsFixed(0),
                            color: FocoTheme.seed,
                          ),
                        if (task.ansiedad >= 4)
                          const _Tag(
                            icon: Icons.psychology_alt_outlined,
                            label: 'Bloquea',
                            color: FocoTheme.peligro,
                          ),
                      ],
                    ),
                    if (mostrarRazon && score != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.tips_and_updates_outlined,
                              size: 14, color: FocoTheme.acento),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              score!.razon,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: FocoTheme.acento,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (onToggleActiva != null)
                IconButton(
                  tooltip: task.activa ? 'Quitar foco' : 'Marcar foco activo',
                  icon: Icon(
                    task.activa ? Icons.star : Icons.star_border,
                    color: task.activa ? FocoTheme.acento : Colors.white38,
                  ),
                  onPressed: onToggleActiva,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompleteButton extends StatelessWidget {
  final bool completada;
  final VoidCallback onTap;
  const _CompleteButton({required this.completada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        completada ? Icons.check_circle : Icons.radio_button_unchecked,
        color: completada ? FocoTheme.acento : Colors.white38,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Tag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DeadlineTag extends StatelessWidget {
  final Task task;
  const _DeadlineTag({required this.task});

  @override
  Widget build(BuildContext context) {
    final d = task.diasRestantes;
    if (d == null) {
      return const _Tag(
          icon: Icons.all_inclusive,
          label: 'Sin fecha',
          color: Colors.white38);
    }
    String label;
    Color color;
    if (d < 0) {
      label = 'Venció hace ${-d} d';
      color = FocoTheme.peligro;
    } else if (d == 0) {
      label = 'Hoy';
      color = FocoTheme.peligro;
    } else if (d == 1) {
      label = 'Mañana';
      color = const Color(0xFFE3A94F);
    } else if (d <= 5) {
      label = 'En $d días';
      color = const Color(0xFFE3A94F);
    } else {
      label = 'En $d días';
      color = Colors.white54;
    }
    return _Tag(icon: Icons.event_outlined, label: label, color: color);
  }
}
