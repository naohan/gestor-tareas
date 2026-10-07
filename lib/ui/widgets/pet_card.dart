import 'package:flutter/material.dart';

import '../../core/pet_state.dart';
import '../../theme.dart';

/// Refleja tu estado emocional, no es un Tamagotchi. Cambia según la carga,
/// lo vencido y los cierres recientes.
class PetCard extends StatelessWidget {
  final PetState pet;
  const PetCard({super.key, required this.pet});

  Color get _tint {
    switch (pet.mood) {
      case PetMood.motivada:
        return FocoTheme.acento;
      case PetMood.tranquila:
        return FocoTheme.seed;
      case PetMood.enfocada:
        return const Color(0xFF9B6DE3);
      case PetMood.saturada:
        return const Color(0xFFE3A94F);
      case PetMood.abrumada:
        return FocoTheme.peligro;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_tint.withValues(alpha: 0.22), FocoTheme.superficie],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              pet.mood.emoji,
              key: ValueKey(pet.mood),
              style: const TextStyle(fontSize: 44),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.mood.titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _tint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pet.mensaje,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white70, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
