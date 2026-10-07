import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foco/data/local_repository.dart';
import 'package:foco/models/task.dart';
import 'package:foco/state/app_state.dart';
import 'package:foco/state/auth_state.dart';
import 'package:foco/theme.dart';
import 'package:foco/ui/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _estado() async {
  final app = AppState(LocalRepository());
  await app.load();
  return app;
}

Set<String> _ids(Iterable<dynamic> logros) =>
    logros.map((a) => a.id as String).toSet();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('completar la primera tarea desbloquea y se celebra una sola vez',
      () async {
    final app = await _estado();
    final t = app.addTask(titulo: 'Informe', categoria: TaskCategory.trabajo);
    expect(app.logrosNuevos, isEmpty);

    app.toggleCompletada(t.id);
    expect(_ids(app.logrosNuevos), {'primer_cierre'});

    await app.marcarLogrosVistos();
    expect(app.logrosNuevos, isEmpty);
    expect(_ids(app.logrosDesbloqueados), contains('primer_cierre'));
  });

  test('un logro ganado no se pierde al reabrir o borrar la tarea', () async {
    final app = await _estado();
    final t = app.addTask(titulo: 'Informe', categoria: TaskCategory.trabajo);
    app.toggleCompletada(t.id);
    await app.marcarLogrosVistos();

    app.toggleCompletada(t.id);
    expect(_ids(app.logrosDesbloqueados), contains('primer_cierre'));
    app.deleteTask(t.id);
    expect(_ids(app.logrosDesbloqueados), contains('primer_cierre'));

    // Volver a completar otra tarea no lo celebra de nuevo.
    final otra = app.addTask(titulo: 'Otra', categoria: TaskCategory.trabajo);
    app.toggleCompletada(otra.id);
    expect(_ids(app.logrosNuevos), isNot(contains('primer_cierre')));
  });

  test('los logros vistos se recuerdan al volver a abrir la app', () async {
    final app = await _estado();
    final t = app.addTask(titulo: 'Informe', categoria: TaskCategory.trabajo);
    app.toggleCompletada(t.id);
    await app.marcarLogrosVistos();
    app.deleteTask(t.id);
    await Future<void>.delayed(Duration.zero);

    final reabierta = await _estado();
    expect(_ids(reabierta.logrosDesbloqueados), contains('primer_cierre'));
    expect(reabierta.logrosNuevos, isEmpty);
  });

  test('entrega anticipada, ansiedad alta y proyecto', () async {
    final app = await _estado();
    final manana = DateTime.now().add(const Duration(days: 1));
    final t = app.addTask(
      titulo: 'Entregar propuesta',
      fechaLimite: DateTime(manana.year, manana.month, manana.day),
      ansiedad: 4,
      categoria: TaskCategory.proyecto,
    );
    app.toggleCompletada(t.id);
    expect(_ids(app.logrosNuevos),
        containsAll({'antes_de_fecha', 'mente_despejada', 'primer_proyecto'}));
  });

  test('racha de 3 días seguidos', () async {
    final app = await _estado();
    final hoy = DateTime.now();
    for (var d = 0; d < 3; d++) {
      final t = app.addTask(titulo: 'Día $d', categoria: TaskCategory.trabajo);
      app.toggleCompletada(t.id);
      app.updateTask(app.tasks
          .firstWhere((x) => x.id == t.id)
          .copyWith(completadaEn: hoy.subtract(Duration(days: d))));
    }
    expect(_ids(app.logrosNuevos), contains('enfoque_3_dias'));
  });

  testWidgets('al completar una tarea aparece la celebración sin recargar',
      (tester) async {
    await initializeDateFormatting('es');
    final app = AppState(LocalRepository());
    await tester.runAsync(app.load);
    final t = app.addTask(titulo: 'Informe', categoria: TaskCategory.trabajo);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider.value(value: app),
      ],
      child: MaterialApp(theme: FocoTheme.dark, home: const HomeScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('¡Logro desbloqueado!'), findsNothing);

    app.toggleCompletada(t.id);
    await tester.pumpAndSettle();
    expect(find.text('¡Logro desbloqueado!'), findsOneWidget);
    expect(find.text('Primer cierre'), findsOneWidget);

    await tester.tap(find.text('¡Bien!'));
    await tester.pumpAndSettle();
    expect(find.text('¡Logro desbloqueado!'), findsNothing);
  });
}
