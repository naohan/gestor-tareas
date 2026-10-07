// Prueba contra el backend real. Se omite salvo que se indique la URL:
//   flutter test test/backend_e2e_test.dart --dart-define=E2E_API_URL=http://localhost:3000
import 'package:flutter_test/flutter_test.dart';
import 'package:foco/data/api_client.dart';
import 'package:foco/data/api_repository.dart';
import 'package:foco/models/task.dart';
import 'package:foco/state/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _url = String.fromEnvironment('E2E_API_URL');

void main() {
  final email = 'e2e-${DateTime.now().millisecondsSinceEpoch}@foco.test';

  test('registro, sincronización e inicio de sesión contra el backend',
      () async {
    SharedPreferences.setMockInitialValues({});

    // Registro.
    final auth = AuthState(api: ApiClient(_url));
    await auth.init();
    expect(auth.status, AuthStatus.sinSesion);
    await auth.registrar(
        nombre: 'Prueba E2E', email: email, password: 'clave-segura-123');
    expect(auth.status, AuthStatus.conSesion);
    expect(auth.user!.email, email);

    // La prueba no deja datos en la base: al terminar elimina su cuenta.
    final limpieza = ApiClient(_url)..token = auth.api!.token;
    addTearDown(() => limpieza
        .delete('/api/auth/me', {'password': 'clave-segura-123'})
        .catchError((_) => <String, dynamic>{}));

    // Una tarea creada "por voz" se guarda en MySQL.
    final repo = ApiRepository(api: auth.api!, userId: auth.user!.id);
    expect((await repo.load()).tasks, isEmpty);
    final tarea = Task(
      id: const Uuid().v4(),
      titulo: 'Terminar Geotón',
      fechaLimite: DateTime(2026, 10, 9),
      horasEstimadas: 2,
      urgencia: 5,
      estado: TaskStatus.enProgreso,
    );
    await repo.saveTasks([tarea]);
    repo.dispose();

    // Otro dispositivo: inicia sesión y recibe la tarea.
    SharedPreferences.setMockInitialValues({});
    final auth2 = AuthState(api: ApiClient(_url));
    await auth2.init();
    await expectLater(
      auth2.login(email: email, password: 'incorrecta'),
      throwsA(isA<ApiException>()
          .having((e) => e.mensaje, 'mensaje', 'Email o contraseña incorrectos')),
    );
    await auth2.login(email: email.toUpperCase(), password: 'clave-segura-123');
    final snap =
        await ApiRepository(api: auth2.api!, userId: auth2.user!.id).load();
    final t = snap.tasks.single;
    expect(t.titulo, 'Terminar Geotón');
    expect(t.fechaLimite, DateTime(2026, 10, 9));
    expect(t.urgencia, 5);
    expect(t.estado, TaskStatus.enProgreso);

    // Cerrar sesión borra el token del dispositivo.
    await auth2.cerrarSesion();
    expect(auth2.status, AuthStatus.sinSesion);
    expect(auth2.api!.token, isNull);
  }, skip: _url.isEmpty ? 'Define E2E_API_URL para probar contra el backend' : false);
}
