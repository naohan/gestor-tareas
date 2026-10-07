import 'package:flutter_test/flutter_test.dart';
import 'package:foco/core/priority_engine.dart';
import 'package:foco/data/local_repository.dart';
import 'package:foco/models/task.dart';

Task _t(
  String id, {
  int impacto = 3,
  int urgencia = 3,
  int ansiedad = 3,
  int? diasParaFecha,
  List<String>? deps,
  bool completada = false,
  double horas = 1,
}) {
  return Task(
    id: id,
    titulo: id,
    impacto: impacto,
    urgencia: urgencia,
    ansiedad: ansiedad,
    horasEstimadas: horas,
    fechaLimite: diasParaFecha == null
        ? null
        : DateTime.now().add(Duration(days: diasParaFecha)),
    dependencias: deps,
    estado: completada ? TaskStatus.completada : TaskStatus.pendiente,
  );
}

void main() {
  group('PriorityEngine', () {
    test('mayor impacto+urgencia gana', () {
      final geoton = _t('Geotón', urgencia: 5, impacto: 4, diasParaFecha: 2);
      final aws = _t('AWS', urgencia: 1, impacto: 3, diasParaFecha: 60);

      final orden = PriorityEngine.priorizar([aws, geoton]);
      expect(orden.first.task.id, 'Geotón');
    });

    test('una tarea con dependencia sin cerrar queda bloqueada', () {
      final base = _t('Base');
      final dependiente = _t('Dependiente', deps: ['Base']);

      final orden = PriorityEngine.priorizar([base, dependiente]);
      final dep = orden.firstWhere((s) => s.task.id == 'Dependiente');
      expect(dep.bloqueada, isTrue);
      // Las bloqueadas van al final.
      expect(orden.last.task.id, 'Dependiente');
    });

    test('si la dependencia está completada, deja de estar bloqueada', () {
      final base = _t('Base', completada: true);
      final dependiente = _t('Dependiente', deps: ['Base']);

      final bloqueada =
          PriorityEngine.estaBloqueada(dependiente, [base, dependiente]);
      expect(bloqueada, isFalse);
    });

    test('a igual puntaje, más ansiedad va primero', () {
      final a = _t('A', urgencia: 3, impacto: 3, ansiedad: 1);
      final b = _t('B', urgencia: 3, impacto: 3, ansiedad: 5);

      final orden = PriorityEngine.priorizar([a, b]);
      expect(orden.first.task.id, 'B');
    });

    test('la recomendación nunca es una tarea bloqueada', () {
      final base = _t('Base', urgencia: 1, impacto: 1);
      final dependiente =
          _t('Dependiente', urgencia: 5, impacto: 5, deps: ['Base']);

      final reco = PriorityEngine.recomendacion([base, dependiente]);
      expect(reco, isNotNull);
      expect(reco!.task.id, 'Base');
    });
  });

  group('nivel de prioridad', () {
    PriorityLevel nivel(Task t) => PriorityEngine.score(t).nivel;

    test('máximo impacto y urgencia sin fecha es "muy alta"', () {
      expect(nivel(_t('x', urgencia: 5, impacto: 5)), PriorityLevel.muyAlta);
    });

    test('valores medios sin fecha es "media"', () {
      expect(nivel(_t('x')), PriorityLevel.media);
    });

    test('la fecha cercana sube el nivel', () {
      expect(nivel(_t('x', diasParaFecha: 1)), PriorityLevel.muyAlta);
    });

    test('poco impacto, poca urgencia y fecha lejana es "baja"', () {
      expect(
        nivel(_t('x', urgencia: 1, impacto: 1, diasParaFecha: 90)),
        PriorityLevel.baja,
      );
    });
  });

  group('migración de escala 0–10', () {
    test('convierte los ejes antiguos a 1–5', () {
      final m = LocalRepository.migrarEjesV1(
          {'impacto': 10, 'urgencia': 0, 'ansiedad': 7});
      expect(m['impacto'], 5);
      expect(m['urgencia'], 1);
      expect(m['ansiedad'], 4);
    });
  });
}
