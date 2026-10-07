import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/api_repository.dart';
import 'data/foco_repository.dart';
import 'data/local_repository.dart';
import 'state/app_state.dart';
import 'state/auth_state.dart';
import 'theme.dart';
import 'ui/auth_screen.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthState()..init(),
      child: const FocoApp(),
    ),
  );
}

class FocoApp extends StatelessWidget {
  const FocoApp({super.key});

  MaterialApp _app({Key? key, required Widget home}) => MaterialApp(
        key: key,
        title: 'Foco',
        debugShowCheckedModeBanner: false,
        theme: FocoTheme.dark,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    switch (auth.status) {
      case AuthStatus.cargando:
        return _app(
          home: const Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      case AuthStatus.sinSesion:
        return _app(key: const ValueKey('acceso'), home: const AuthScreen());
      case AuthStatus.local:
      case AuthStatus.conSesion:
        final user = auth.user;
        final sesion = user == null ? 'local' : 'u:${user.id}';
        // AppState vive por encima del MaterialApp para que las pantallas que
        // se abren con Navigator también lo vean; la clave lo recrea al
        // cambiar de cuenta.
        return ChangeNotifierProvider(
          key: ValueKey(sesion),
          create: (_) => AppState(_repositorio(auth))..load(),
          child: _app(key: ValueKey('app-$sesion'), home: const HomeScreen()),
        );
    }
  }

  static FocoRepository _repositorio(AuthState auth) {
    final user = auth.user;
    if (user == null) return LocalRepository();
    return ApiRepository(
      api: auth.api!,
      userId: user.id,
      onUnauthorized: () => auth.cerrarSesion(caducada: true),
    );
  }
}
