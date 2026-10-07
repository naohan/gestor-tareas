import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/achievement.dart';
import '../state/app_state.dart';
import '../theme.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final desbloqueados =
        app.logrosDesbloqueados.map((a) => a.id).toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Logros')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Aquí no se premia la cantidad. Se premia el cierre.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 16),
          ...Achievements.all.map((a) {
            final unlocked = desbloqueados.contains(a.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: unlocked ? 1 : 0.45,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Text(a.emoji,
                            style: const TextStyle(fontSize: 30)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.titulo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(a.descripcion,
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 13)),
                            ],
                          ),
                        ),
                        Icon(
                          unlocked
                              ? Icons.check_circle
                              : Icons.lock_outline,
                          color: unlocked
                              ? FocoTheme.acento
                              : Colors.white24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
