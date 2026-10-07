import 'package:flutter_test/flutter_test.dart';
import 'package:foco/core/block_planner.dart';
import 'package:foco/models/calendar_event.dart';
import 'package:foco/models/planner_models.dart';
import 'package:foco/models/task.dart';

CalendarEvent _busy(DateTime ini, DateTime fin) => CalendarEvent(
      id: '${ini.hour}',
      titulo: 'Ocupado',
      inicio: ini,
      fin: fin,
    );

void main() {
  group('huecosLibres', () {
    test('un día sin ocupaciones da un único hueco de toda la jornada', () {
      final lunes = DateTime(2026, 6, 8, 0); // jornada 9-18 => 9h
      final libres = BlockPlanner.huecosLibres(
        desde: lunes,
        dias: 1,
        ocupados: const [],
      );
      expect(libres.length, 1);
      expect(libres.first.inicio.hour, 9);
      expect(libres.first.fin.hour, 18);
    });

    test('el primer día empieza en el siguiente cuarto de hora', () {
      final libres = BlockPlanner.huecosLibres(
        desde: DateTime(2026, 6, 8, 11, 38, 20),
        dias: 1,
        ocupados: const [],
      );
      expect(libres.first.inicio, DateTime(2026, 6, 8, 11, 45));
    });

    test('una reunión parte la jornada en dos huecos', () {
      final dia = DateTime(2026, 6, 8, 0);
      final reunion = _busy(
        DateTime(2026, 6, 8, 11),
        DateTime(2026, 6, 8, 12),
      );
      final libres = BlockPlanner.huecosLibres(
        desde: dia,
        dias: 1,
        ocupados: [reunion],
      );
      expect(libres.length, 2);
      expect(libres[0].inicio.hour, 9);
      expect(libres[0].fin.hour, 11);
      expect(libres[1].inicio.hour, 12);
      expect(libres[1].fin.hour, 18);
    });
  });

  group('planificar', () {
    test('respeta el orden de prioridad y el tope por bloque', () {
      final alta = Task(
        id: 'alta',
        titulo: 'Alta',
        urgencia: 5,
        impacto: 5,
        horasEstimadas: 2,
        activa: true,
      );
      final baja = Task(
        id: 'baja',
        titulo: 'Baja',
        urgencia: 1,
        impacto: 1,
        horasEstimadas: 1,
        activa: true,
      );

      final libres = BlockPlanner.huecosLibres(
        desde: DateTime(2026, 6, 8, 0),
        dias: 1,
        ocupados: const [],
      );
      final bloques = BlockPlanner.planificar(
        tareasActivas: [baja, alta],
        huecos: libres,
        maxMinutosBloque: 90,
        minutosDescanso: 15,
      );

      expect(bloques, isNotEmpty);
      // La de mayor prioridad va primero.
      expect(bloques.first.task.id, 'alta');
      // Ningún bloque supera 90 min.
      for (final b in bloques) {
        expect(b.duracion.inMinutes <= 90, isTrue);
      }
    });

    test('no usa huecos demasiado cortos para enfocarse', () {
      final t = Task(id: 't', titulo: 'T', horasEstimadas: 1, activa: true);
      final dia = DateTime(2026, 6, 8);
      final huecos = [
        FreeSlot(dia.add(const Duration(hours: 9)),
            dia.add(const Duration(hours: 9, minutes: 15))),
        FreeSlot(dia.add(const Duration(hours: 10)),
            dia.add(const Duration(hours: 12))),
      ];
      final bloques = BlockPlanner.planificar(tareasActivas: [t], huecos: huecos);
      expect(bloques.length, 1);
      expect(bloques.first.inicio.hour, 10);
    });

    test('descarta un resto pequeño en lugar de crear un bloque mínimo', () {
      // 100 min con tope de 90 => sobran 10 min, que no se agendan.
      final t = Task(
          id: 't', titulo: 'T', horasEstimadas: 100 / 60, activa: true);
      final libres = BlockPlanner.huecosLibres(
        desde: DateTime(2026, 6, 8),
        dias: 1,
        ocupados: const [],
      );
      final bloques = BlockPlanner.planificar(tareasActivas: [t], huecos: libres);
      expect(bloques.length, 1);
      expect(bloques.first.duracion.inMinutes, 90);
    });

    test('no planifica tareas bloqueadas por dependencias', () {
      final base = Task(id: 'base', titulo: 'Base', activa: true);
      final dep = Task(
        id: 'dep',
        titulo: 'Dependiente',
        activa: true,
        dependencias: ['base'],
      );
      final libres = BlockPlanner.huecosLibres(
        desde: DateTime(2026, 6, 8, 0),
        dias: 1,
        ocupados: const [],
      );
      final bloques = BlockPlanner.planificar(
        tareasActivas: [base, dep],
        huecos: libres,
      );
      expect(bloques.any((b) => b.task.id == 'dep'), isFalse);
    });
  });
}
