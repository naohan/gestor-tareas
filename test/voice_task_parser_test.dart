import 'package:flutter_test/flutter_test.dart';
import 'package:foco/core/voice_task_parser.dart';
import 'package:foco/models/task.dart';

void main() {
  // Miércoles 7 de octubre de 2026.
  final hoy = DateTime(2026, 10, 7, 11, 30);
  VoiceTaskDraft p(String frase, {DateTime? dia}) =>
      VoiceTaskParser.parse(frase, hoy: dia ?? hoy);

  test('título, día de la semana, urgencia y horas', () {
    final d = p('Terminar Geotón para el viernes, es urgente, me toma dos horas');
    expect(d.titulo, 'Terminar Geotón');
    expect(d.fechaLimite, DateTime(2026, 10, 9));
    expect(d.urgencia, 5);
    expect(d.horasEstimadas, 2);
  });

  test('fecha con mes, ansiedad y categoría inferida', () {
    final d = p('Tengo que estudiar para el examen de AWS el 15 de octubre, me agobia');
    expect(d.titulo, 'Estudiar para el examen de AWS');
    expect(d.fechaLimite, DateTime(2026, 10, 15));
    expect(d.ansiedad, 5);
    expect(d.categoria, TaskCategory.estudio);
  });

  test('"mañana" y "media hora"', () {
    final d = p('Preparar reunión de Mar de Becas mañana, media hora');
    expect(d.titulo, 'Preparar reunión de Mar de Becas');
    expect(d.fechaLimite, DateTime(2026, 10, 8));
    expect(d.horasEstimadas, 0.5);
    expect(d.categoria, TaskCategory.trabajo);
  });

  test('"en 3 días" y "no es urgente"', () {
    final d = p('Comprar regalo de cumpleaños en 3 días, no es urgente');
    expect(d.titulo, 'Comprar regalo de cumpleaños');
    expect(d.fechaLimite, DateTime(2026, 10, 10));
    expect(d.urgencia, 1);
    expect(d.categoria, TaskCategory.personal);
  });

  test('"el próximo lunes" y "una hora y media"', () {
    final d = p('Cita con el dentista el próximo lunes, una hora y media');
    expect(d.titulo, 'Cita con el dentista');
    expect(d.fechaLimite, DateTime(2026, 10, 12));
    expect(d.horasEstimadas, 1.5);
    expect(d.categoria, TaskCategory.salud);
  });

  test('"por la mañana" no es una fecha', () {
    final d = p('Llamar a Fiscamoto por la mañana, es muy importante');
    expect(d.titulo, 'Llamar a Fiscamoto por la mañana');
    expect(d.fechaLimite, isNull);
    expect(d.impacto, 5);
  });

  test('categoría dicha explícitamente y "hoy"', () {
    final d = p('Revisar presupuesto categoría proyecto para hoy');
    expect(d.titulo, 'Revisar presupuesto');
    expect(d.categoria, TaskCategory.proyecto);
    expect(d.fechaLimite, DateTime(2026, 10, 7));
  });

  test('el mismo día de la semana se refiere a la semana siguiente', () {
    final viernes = DateTime(2026, 10, 9);
    expect(p('Entregar informe el viernes', dia: viernes).fechaLimite,
        DateTime(2026, 10, 16));
  });

  test('minutos y muletillas de inicio', () {
    final d = p('Crear una tarea de responder correos, 30 minutos');
    expect(d.titulo, 'Responder correos');
    expect(d.horasEstimadas, 0.5);
  });

  test('sin título no se puede guardar', () {
    expect(p('mañana').tieneTitulo, isFalse);
  });

  test('una frase simple queda intacta', () {
    final d = p('Tareas del hogar');
    expect(d.titulo, 'Tareas del hogar');
    expect(d.fechaLimite, isNull);
    expect(d.urgencia, isNull);
  });
}
