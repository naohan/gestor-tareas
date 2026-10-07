import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foco/core/voice_task_parser.dart';
import 'package:foco/data/local_repository.dart';
import 'package:foco/state/app_state.dart';
import 'package:foco/theme.dart';
import 'package:foco/ui/task_editor.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _montar(WidgetTester tester, Size size,
    {VoiceTaskDraft? borrador}) async {
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('es');
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AppState(LocalRepository()),
      child: MaterialApp(
        theme: FocoTheme.dark,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: TaskEditor(borrador: borrador),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('móvil: una columna con fecha y tiempo lado a lado, sin desbordes',
      (tester) async {
    await _montar(tester, const Size(360, 800));
    expect(tester.takeException(), isNull);

    final info = tester.getTopLeft(find.text('Información de la tarea'));
    final prioridad = tester.getTopLeft(find.text('Prioridad de la tarea'));
    expect(prioridad.dy, greaterThan(info.dy));

    final fecha = tester.getTopLeft(find.text('Fecha límite'));
    final tiempo = tester.getTopLeft(find.text('Tiempo estimado'));
    expect(tiempo.dy, fecha.dy);
    expect(find.text('Crear tarea'), findsOneWidget);
  });

  testWidgets('escritorio: información a la izquierda, prioridad a la derecha',
      (tester) async {
    await _montar(tester, const Size(1280, 900));
    expect(tester.takeException(), isNull);

    final info = tester.getTopLeft(find.text('Información de la tarea'));
    final prioridad = tester.getTopLeft(find.text('Prioridad de la tarea'));
    expect(prioridad.dy, info.dy);
    expect(prioridad.dx, greaterThan(info.dx + 400));

    final fecha = tester.getTopLeft(find.text('Fecha límite'));
    final tiempo = tester.getTopLeft(find.text('Tiempo estimado'));
    expect(tiempo.dy, fecha.dy);
  });

  testWidgets('tablet: una columna centrada sin desbordes', (tester) async {
    await _montar(tester, const Size(800, 1000));
    expect(tester.takeException(), isNull);
    final info = tester.getTopLeft(find.text('Información de la tarea'));
    final prioridad = tester.getTopLeft(find.text('Prioridad de la tarea'));
    expect(prioridad.dy, greaterThan(info.dy));
  });

  testWidgets('un borrador dictado rellena el formulario y sube la prioridad',
      (tester) async {
    final hoy = DateTime.now();
    await _montar(
      tester,
      const Size(360, 800),
      borrador: VoiceTaskParser.parse(
          'Terminar Geotón mañana, es urgente, muy importante, me toma dos horas',
          hoy: hoy),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Terminar Geotón'), findsOneWidget);
    expect(find.text('2 h'), findsOneWidget);
    expect(find.text('Muy urgente'), findsOneWidget);
    expect(find.text('Muy alto'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('MUY ALTA'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('MUY ALTA'), findsOneWidget);
  });
}
