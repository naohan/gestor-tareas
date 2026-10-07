import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foco/data/api_client.dart';
import 'package:foco/data/api_repository.dart';
import 'package:foco/models/task.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backend falso en memoria que registra las peticiones.
class _Backend {
  bool caido = false;
  int status = 200;
  List<Map<String, dynamic>> tasks = [];
  final puts = <String, List<Map<String, dynamic>>>{};

  int putsA(String ruta) => puts[ruta]?.length ?? 0;

  late final client = MockClient((req) async {
    if (caido) throw http.ClientException('sin red');
    if (status != 200) {
      return http.Response(jsonEncode({'error': 'Token inválido o caducado'}),
          status);
    }
    if (req.method == 'GET' && req.url.path == '/api/sync') {
      return http.Response(
          jsonEncode({'tasks': tasks, 'projects': [], 'achievements': []}),
          200);
    }
    if (req.method == 'PUT') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      (puts[req.url.path] ??= []).add(body);
      if (req.url.path == '/api/sync/tasks') {
        tasks = (body['tasks'] as List).cast<Map<String, dynamic>>();
      }
      return http.Response(jsonEncode({'ok': true}), 200);
    }
    return http.Response('{}', 404);
  });
}

void main() {
  late _Backend backend;
  late ApiClient api;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = _Backend();
    api = ApiClient('http://api.test', client: backend.client)..token = 't';
  });

  ApiRepository repo({void Function()? onUnauthorized}) => ApiRepository(
      api: api, userId: 'u1', onUnauthorized: onUnauthorized);

  test('formato de la API: estado, fecha y marcas de tiempo', () {
    final t = Task(
      id: 'a',
      titulo: 'Informe',
      estado: TaskStatus.enProgreso,
      fechaLimite: DateTime(2026, 10, 9),
      completadaEn: DateTime.utc(2026, 10, 7, 15, 30),
      creada: DateTime.utc(2026, 10, 1, 8),
      impacto: 5,
      dependencias: ['b'],
    );
    final wire = ApiRepository.taskToWire(t);
    expect(wire['estado'], 'en_progreso');
    expect(wire['fechaLimite'], '2026-10-09');
    expect(wire['completadaEn'], '2026-10-07T15:30:00.000Z');

    final vuelta = ApiRepository.taskFromWire({
      ...wire,
      'completadaEn': '2026-10-07T15:30:00Z',
      'creada': '2026-10-01T08:00:00Z',
    });
    expect(vuelta.estado, TaskStatus.enProgreso);
    expect(vuelta.fechaLimite, DateTime(2026, 10, 9));
    expect(vuelta.completadaEn!.isAtSameMomentAs(t.completadaEn!), isTrue);
    expect(vuelta.impacto, 5);
    expect(vuelta.dependencias, ['b']);
  });

  test('la primera cuenta importa las tareas del modo sin cuenta', () async {
    final local = Task(id: 'local-1', titulo: 'Tarea sin cuenta');
    SharedPreferences.setMockInitialValues({
      'foco_tasks_v2': jsonEncode([local.toJson()]),
    });

    final snap = await repo().load();
    expect(snap.tasks.map((t) => t.id), ['local-1']);
    expect(backend.tasks.single['id'], 'local-1');

    // Si luego la cuenta queda vacía, no se vuelve a importar.
    backend.tasks = [];
    final otra = await repo().load();
    expect(otra.tasks, isEmpty);
    expect(backend.putsA('/api/sync/tasks'), 1);
  });

  test('sin red guarda en local y lo sube al volver la conexión', () async {
    final r = repo();
    await r.load();
    backend.caido = true;
    await r.saveTasks([Task(id: 'x', titulo: 'Offline')]);
    r.dispose();
    expect(backend.tasks, isEmpty);

    backend.caido = false;
    backend.tasks = [];
    final snap = await repo().load();
    expect(snap.tasks.single.titulo, 'Offline');
    expect(backend.tasks.single['titulo'], 'Offline');
  });

  test('un 401 cierra la sesión', () async {
    var cerrada = false;
    backend.status = 401;
    await repo(onUnauthorized: () => cerrada = true).load();
    expect(cerrada, isTrue);
  });

  test('cambios seguidos se agrupan y llega el último', () async {
    final r = repo();
    await r.load();
    final futuros = [
      for (var i = 1; i <= 5; i++)
        r.saveTasks([for (var j = 0; j < i; j++) Task(id: '$j', titulo: 'T$j')]),
    ];
    await Future.wait(futuros);
    expect(backend.putsA('/api/sync/tasks'), lessThanOrEqualTo(2));
    expect(backend.tasks.length, 5);
  });
}
