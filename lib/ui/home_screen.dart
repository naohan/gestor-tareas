import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/priority_engine.dart';
import '../models/achievement.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import 'achievements_screen.dart';
import 'planner_screen.dart';
import 'task_editor.dart';
import 'voice_capture_sheet.dart';
import 'widgets/pet_card.dart';
import 'widgets/task_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _celebrando = false;

  /// Se revisa en cada cambio de tareas, así un logro se celebra en cuanto
  /// se consigue (también si se completa desde otra pantalla).
  void _maybeCelebrar(AppState app) {
    if (_celebrando || !app.loaded) return;
    final nuevos = app.logrosNuevos;
    if (nuevos.isEmpty) return;
    _celebrando = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      app.marcarLogrosVistos();
      await _mostrarLogros(nuevos);
      _celebrando = false;
    });
  }

  Future<void> _mostrarLogros(List<Achievement> nuevos) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FocoTheme.superficie,
        title: const Text('¡Logro desbloqueado!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: nuevos
              .map((a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text(a.emoji,
                            style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.titulo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(a.descripcion,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white60)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('¡Bien!'),
          ),
        ],
      ),
    );
  }

  void _abrirEditor([Task? task]) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskEditor(task: task)),
    );
  }

  Future<void> _crearPorVoz() async {
    final r = await mostrarCapturaPorVoz(context);
    if (r == null || !mounted) return;
    final d = r.draft;
    if (r.editar) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskEditor(borrador: d)),
      );
      return;
    }
    final app = context.read<AppState>();
    final task = app.addTask(
      titulo: d.titulo,
      fechaLimite: d.fechaLimite,
      horasEstimadas: d.horasEstimadas ?? 1,
      categoria: d.categoria ?? TaskCategory.proyecto,
      impacto: d.impacto ?? 3,
      urgencia: d.urgencia ?? 3,
      ansiedad: d.ansiedad ?? 3,
    );
    final nivel = PriorityEngine.score(task).nivel;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Guardada: «${task.titulo}» · Prioridad ${nivel.label.toLowerCase()}'),
        action: SnackBarAction(
          label: 'Editar',
          onPressed: () => _abrirEditor(task),
        ),
      ),
    );
  }

  void _activar(AppState app, String id) {
    final ok = app.toggleActiva(id);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Ya tienes 3 focos activos. Cierra o suelta uno antes de sumar otro.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    _maybeCelebrar(app);

    if (!app.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final activas = app.activas;
    final enEspera = app.enEspera;
    final bloqueadas = app.bloqueadas;
    final reco = app.recomendacion;
    final hayTareas = app.tasks.any((t) => !t.completada);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Foco',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Tooltip(
            message: app.sincronizaRemoto
                ? 'Sincronizado con tu cuenta'
                : 'Guardando solo en este dispositivo',
            child: Icon(
              app.sincronizaRemoto ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              size: 20,
              color: app.sincronizaRemoto ? FocoTheme.acento : Colors.white38,
            ),
          ),
          IconButton(
            tooltip: 'Planificador',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PlannerScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Completadas',
            icon: const Icon(Icons.history),
            onPressed: () => _mostrarCompletadas(app),
          ),
          IconButton(
            tooltip: 'Logros',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const AchievementsScreen()),
            ),
          ),
          const _MenuCuenta(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'voz',
            tooltip: 'Crear tarea por voz',
            backgroundColor: FocoTheme.superficie2,
            foregroundColor: FocoTheme.acento,
            onPressed: _crearPorVoz,
            child: const Icon(Icons.mic),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'nueva',
            onPressed: () => _abrirEditor(),
            icon: const Icon(Icons.add),
            label: const Text('Nueva'),
          ),
        ],
      ),
      body: hayTareas
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                PetCard(pet: app.pet),
                const SizedBox(height: 16),
                if (reco != null) _RecomendacionCard(score: reco, onEmpezar: () {
                  if (!reco.task.activa) _activar(app, reco.task.id);
                }),
                const SizedBox(height: 20),
                _Seccion(
                  titulo: 'Focos activos',
                  trailing: _Contador(
                    actual: activas.length,
                    max: PriorityEngine.maxObjetivosActivos,
                  ),
                ),
                if (activas.isEmpty)
                  const _Hint(
                      'Marca con ⭐ hasta 3 tareas como foco activo. Solo esas, el resto espera.')
                else
                  ...activas.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TaskCard(
                          task: t,
                          onTap: () => _abrirEditor(t),
                          onComplete: () => app.toggleCompletada(t.id),
                          onToggleActiva: () => _activar(app, t.id),
                        ),
                      )),
                const SizedBox(height: 16),
                if (enEspera.isNotEmpty) ...[
                  const _Seccion(titulo: 'En espera'),
                  ...enEspera.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TaskCard(
                          task: s.task,
                          score: s,
                          onTap: () => _abrirEditor(s.task),
                          onComplete: () =>
                              app.toggleCompletada(s.task.id),
                          onToggleActiva: () => _activar(app, s.task.id),
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
                if (bloqueadas.isNotEmpty) ...[
                  const _Seccion(
                    titulo: 'Bloqueadas',
                    subtitulo: 'Dependen de otras tareas',
                  ),
                  ...bloqueadas.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Opacity(
                          opacity: 0.55,
                          child: TaskCard(
                            task: s.task,
                            score: s,
                            mostrarRazon: true,
                            onTap: () => _abrirEditor(s.task),
                          ),
                        ),
                      )),
                ],
              ],
            )
          : _EmptyState(onAdd: () => _abrirEditor(), onVoz: _crearPorVoz),
    );
  }

  void _mostrarCompletadas(AppState app) {
    final completadas = app.completadas;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FocoTheme.superficie,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (ctx, controller) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Completadas',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${completadas.length}',
                        style: const TextStyle(color: Colors.white54)),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: completadas.isEmpty
                      ? const Center(
                          child: Text('Aún no cierras nada. Pronto.',
                              style: TextStyle(color: Colors.white54)),
                        )
                      : ListView.separated(
                          controller: controller,
                          itemCount: completadas.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final t = completadas[i];
                            return TaskCard(
                              task: t,
                              onComplete: () =>
                                  app.toggleCompletada(t.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecomendacionCard extends StatelessWidget {
  final PriorityScore score;
  final VoidCallback onEmpezar;
  const _RecomendacionCard({required this.score, required this.onEmpezar});

  @override
  Widget build(BuildContext context) {
    final t = score.task;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A3A66), FocoTheme.superficie],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FocoTheme.seed.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.center_focus_strong, color: FocoTheme.acento, size: 18),
              SizedBox(width: 6),
              Text('AHORA MISMO',
                  style: TextStyle(
                      color: FocoTheme.acento,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text(t.titulo,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined,
                  size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(score.razon,
                    style: const TextStyle(color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!t.activa)
            FilledButton.icon(
              onPressed: onEmpezar,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Convertir en foco activo'),
            )
          else
            const Row(
              children: [
                Icon(Icons.star, color: FocoTheme.acento, size: 18),
                SizedBox(width: 6),
                Text('Ya es uno de tus focos. A por ello.',
                    style: TextStyle(color: FocoTheme.acento)),
              ],
            ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget? trailing;
  const _Seccion({required this.titulo, this.subtitulo, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              if (subtitulo != null)
                Text(subtitulo!,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white38)),
            ],
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  final int actual;
  final int max;
  const _Contador({required this.actual, required this.max});

  @override
  Widget build(BuildContext context) {
    final lleno = actual >= max;
    final color = lleno ? FocoTheme.peligro : FocoTheme.acento;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$actual / $max',
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FocoTheme.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
    );
  }
}

class _MenuCuenta extends StatelessWidget {
  const _MenuCuenta();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;

    return PopupMenuButton<String>(
      tooltip: 'Cuenta',
      color: FocoTheme.superficie2,
      offset: const Offset(0, 48),
      onSelected: (accion) {
        switch (accion) {
          case 'salir':
            auth.cerrarSesion();
          case 'entrar':
            auth.irAIniciarSesion();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user?.nombre ?? 'Sin cuenta',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              Text(user?.email ?? 'Tus tareas viven solo en este dispositivo',
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (user != null)
          const PopupMenuItem(
            value: 'salir',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout),
              title: Text('Cerrar sesión'),
            ),
          )
        else if (auth.hayBackend)
          const PopupMenuItem(
            value: 'entrar',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.login),
              title: Text('Iniciar sesión o crear cuenta'),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: FocoTheme.seed.withValues(alpha: 0.3),
          child: user == null
              ? const Icon(Icons.person_outline, size: 20, color: Colors.white)
              : Text(user.iniciales,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onVoz;
  const _EmptyState({required this.onAdd, required this.onVoz});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧭', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Tienes diez cosas pendientes.\n¿Cuál hacer ahora mismo?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
            ),
            const SizedBox(height: 10),
            const Text(
              'Foco no te ayuda a registrar tareas. Te ayuda a decidir qué hacer cuando estás abrumada.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Añadir tu primera tarea'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onVoz,
              icon: const Icon(Icons.mic),
              label: const Text('O díctala en voz alta'),
            ),
          ],
        ),
      ),
    );
  }
}
