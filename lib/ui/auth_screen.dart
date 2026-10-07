import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/api_client.dart';
import '../state/auth_state.dart';
import '../theme.dart';

/// Inicio de sesión y registro. También permite seguir sin cuenta.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _registro = false;
  bool _enviando = false;
  bool _verPassword = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando || !_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    try {
      if (_registro) {
        await auth.registrar(
          nombre: _nombre.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await auth.login(email: _email.text, password: _password.text);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _cambiarModo(bool registro) {
    setState(() {
      _registro = registro;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final aviso = auth.aviso;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('🧭',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      const Text('Foco',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 30, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text(
                        'Te ayudo a decidir qué hacer cuando estás abrumada.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: FocoTheme.superficie,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                    value: false,
                                    label: Text('Iniciar sesión')),
                                ButtonSegment(
                                    value: true, label: Text('Crear cuenta')),
                              ],
                              selected: {_registro},
                              showSelectedIcon: false,
                              onSelectionChanged: _enviando
                                  ? null
                                  : (s) => _cambiarModo(s.first),
                            ),
                            const SizedBox(height: 20),
                            if (aviso != null && _error == null) ...[
                              _Mensaje(texto: aviso, color: FocoTheme.seed),
                              const SizedBox(height: 14),
                            ],
                            if (_registro) ...[
                              TextFormField(
                                controller: _nombre,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                maxLength: 100,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre',
                                  prefixIcon: Icon(Icons.person_outline),
                                  counterText: '',
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Escribe tu nombre'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: (v) {
                                final t = v?.trim() ?? '';
                                if (t.isEmpty) return 'Escribe tu email';
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(t)) {
                                  return 'Email inválido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              obscureText: !_verPassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: [
                                _registro
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password
                              ],
                              onFieldSubmitted: (_) => _enviar(),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                helperText:
                                    _registro ? 'Mínimo 8 caracteres' : null,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _verPassword
                                      ? 'Ocultar contraseña'
                                      : 'Mostrar contraseña',
                                  icon: Icon(_verPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                  onPressed: () => setState(
                                      () => _verPassword = !_verPassword),
                                ),
                              ),
                              validator: (v) {
                                final t = v ?? '';
                                if (t.isEmpty) return 'Escribe tu contraseña';
                                if (_registro && t.length < 8) {
                                  return 'La contraseña debe tener al menos 8 caracteres';
                                }
                                if (t.length > 72) return 'Máximo 72 caracteres';
                                return null;
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              _Mensaje(texto: _error!, color: FocoTheme.peligro),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _enviando ? null : _enviar,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                              ),
                              child: _enviando
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5),
                                    )
                                  : Text(_registro
                                      ? 'Crear cuenta'
                                      : 'Iniciar sesión'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _enviando ? null : auth.continuarSinCuenta,
                        child: const Text('Continuar sin cuenta'),
                      ),
                      const Text(
                        'Sin cuenta tus tareas se guardan solo en este dispositivo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final String texto;
  final Color color;
  const _Mensaje({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(texto, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}
