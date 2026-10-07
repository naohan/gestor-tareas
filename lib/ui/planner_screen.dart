import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/block_planner.dart';
import '../models/calendar_event.dart';
import '../models/planner_models.dart';
import '../models/task.dart';
import '../config/app_config.dart';
import '../services/calendar_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Planificador: ubica los focos activos en los huecos libres del calendario
/// y permite escribir esos bloques de vuelta (foco_planned). Sin calendario
/// conectado reparte los focos en la jornada, sin inventar ocupaciones.
class PlannerScreen extends StatefulWidget {
  final CalendarService? service;
  const PlannerScreen({super.key, this.service});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  CalendarService? get _cal => widget.service;
  final _uuid = const Uuid();

  static const _dias = 7;

  bool _cargando = true;
  bool _escribiendo = false;
  List<PlannedBlock> _bloques = [];
  List<CalendarEvent> _ocupados = [];

  @override
  void initState() {
    super.initState();
    _planificar();
  }

  Future<void> _planificar() async {
    setState(() => _cargando = true);
    final app = context.read<AppState>();
    final ahora = DateTime.now();
    final hasta = ahora.add(const Duration(days: _dias));

    final ocupados = await _cal?.ocupaciones(ahora, hasta) ?? const [];
    final huecos = BlockPlanner.huecosLibres(
      desde: ahora,
      dias: _dias,
      ocupados: ocupados,
    );
    final bloques = BlockPlanner.planificar(
      tareasActivas: app.activas,
      huecos: huecos,
    );

    if (!mounted) return;
    setState(() {
      _ocupados = ocupados;
      _bloques = bloques;
      _cargando = false;
    });
  }

  Future<void> _escribirEnCalendario(CalendarService cal) async {
    setState(() => _escribiendo = true);
    final eventos = BlockPlanner.bloquesAEventos(
      _bloques,
      nuevoId: () => _uuid.v4(),
    );
    for (final e in eventos) {
      await cal.crearEvento(e);
    }
    if (!mounted) return;
    setState(() => _escribiendo = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${eventos.length} bloque(s) de enfoque escritos en "${cal.cuenta}".'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sinFocos = app.activas.isEmpty;
    final cal = _cal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planificador'),
        actions: [
          IconButton(
            tooltip: 'Recalcular',
            onPressed: _cargando ? null : _planificar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: (cal == null || _bloques.isEmpty || sinFocos)
          ? null
          : FloatingActionButton.extended(
              onPressed: _escribiendo ? null : () => _escribirEnCalendario(cal),
              icon: _escribiendo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_available),
              label: const Text('Escribir en calendario'),
            ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : sinFocos
              ? const _SinFocos()
              : _AgendaView(
                  bloques: _bloques,
                  ocupados: _ocupados,
                  cuenta: cal?.cuenta,
                ),
    );
  }
}

class _AgendaView extends StatelessWidget {
  final List<PlannedBlock> bloques;
  final List<CalendarEvent> ocupados;

  /// Calendario conectado; null si se planifica solo con la jornada.
  final String? cuenta;

  const _AgendaView({
    required this.bloques,
    required this.ocupados,
    required this.cuenta,
  });

  @override
  Widget build(BuildContext context) {
    // Agrupa bloques por día.
    final porDia = <DateTime, List<PlannedBlock>>{};
    for (final b in bloques) {
      final d = DateTime(b.inicio.year, b.inicio.month, b.inicio.day);
      (porDia[d] ??= []).add(b);
    }
    final dias = porDia.keys.toList()..sort();
    final hf = DateFormat.Hm('es');
    final df = DateFormat("EEEE d 'de' MMMM", 'es');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FocoTheme.superficie,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: FocoTheme.acento),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cuenta != null
                      ? 'Agenda: $cuenta\nUbiqué tus focos en los huecos libres de los próximos 7 días.'
                      : 'Sin calendario conectado: repartí tus focos en tu jornada '
                          '(${AppConfig.horaInicioJornada}:00–${AppConfig.horaFinJornada}:00) '
                          'de los próximos 7 días, con descansos entre bloques.',
                  style: const TextStyle(
                      fontSize: 12.5, color: Colors.white70, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (bloques.isEmpty)
          const Text(
            'No hay huecos libres suficientes en los próximos días para tus focos. '
            'Libera algo de agenda o reduce las horas estimadas.',
            style: TextStyle(color: Colors.white54),
          ),
        ...dias.map((dia) {
          final delDia = porDia[dia]!
            ..sort((a, b) => a.inicio.compareTo(b.inicio));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  df.format(dia),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: FocoTheme.acento),
                ),
              ),
              ...delDia.map((b) => _BloqueTile(
                    inicio: hf.format(b.inicio),
                    fin: hf.format(b.fin),
                    titulo: b.task.titulo,
                    color: b.task.categoria.color,
                    minutos: b.duracion.inMinutes,
                  )),
            ],
          );
        }),
      ],
    );
  }
}

class _BloqueTile extends StatelessWidget {
  final String inicio;
  final String fin;
  final String titulo;
  final Color color;
  final int minutos;

  const _BloqueTile({
    required this.inicio,
    required this.fin,
    required this.titulo,
    required this.color,
    required this.minutos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FocoTheme.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(inicio,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(fin,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Enfoque · $minutos min',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.center_focus_strong, color: color, size: 18),
        ],
      ),
    );
  }
}

class _SinFocos extends StatelessWidget {
  const _SinFocos();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🗓️', style: TextStyle(fontSize: 56)),
            SizedBox(height: 16),
            Text(
              'Primero marca tus focos activos',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Vuelve a la pantalla principal y marca con ⭐ hasta 3 tareas. '
              'Aquí las ubicaré en tu agenda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
