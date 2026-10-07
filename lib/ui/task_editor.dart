import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/priority_engine.dart';
import '../core/voice_task_parser.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'voice_capture_sheet.dart';
import 'widgets/priority_widgets.dart';

/// Alta y edición de una tarea. Si [task] es null, se crea una nueva; si
/// llega un [borrador] (dictado por voz), se usa para rellenar el formulario.
class TaskEditor extends StatefulWidget {
  final Task? task;
  final VoiceTaskDraft? borrador;
  const TaskEditor({super.key, this.task, this.borrador});

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  static const _opcionesHoras = [
    0.25,
    0.5,
    1.0,
    1.5,
    2.0,
    3.0,
    4.0,
    6.0,
    8.0,
    12.0,
  ];
  static const _iconoCompacto = BoxConstraints(minWidth: 40, minHeight: 40);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _descripcion;

  DateTime? _fechaLimite;
  double _horas = 1;
  TaskCategory _categoria = TaskCategory.proyecto;
  int _impacto = 3;
  int _urgencia = 3;
  int _ansiedad = 3;
  late List<String> _dependencias;

  bool get _editando => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titulo = TextEditingController(text: t?.titulo ?? '');
    _descripcion = TextEditingController(text: t?.descripcion ?? '');
    _fechaLimite = t?.fechaLimite;
    _horas = t?.horasEstimadas ?? 1;
    _categoria = t?.categoria ?? TaskCategory.proyecto;
    _impacto = t?.impacto ?? 3;
    _urgencia = t?.urgencia ?? 3;
    _ansiedad = t?.ansiedad ?? 3;
    _dependencias = List.of(t?.dependencias ?? const []);
    final b = widget.borrador;
    if (b != null) _aplicarBorrador(b);
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  void _aplicarBorrador(VoiceTaskDraft d) {
    if (d.tieneTitulo) _titulo.text = d.titulo;
    _fechaLimite = d.fechaLimite ?? _fechaLimite;
    _horas = d.horasEstimadas ?? _horas;
    _categoria = d.categoria ?? _categoria;
    _impacto = d.impacto ?? _impacto;
    _urgencia = d.urgencia ?? _urgencia;
    _ansiedad = d.ansiedad ?? _ansiedad;
  }

  Future<void> _dictar() async {
    final r = await mostrarCapturaPorVoz(context, soloDictar: true);
    if (r == null || !mounted) return;
    setState(() => _aplicarBorrador(r.draft));
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final inicial = _fechaLimite ?? hoy;
    final primera = inicial.isBefore(hoy) ? inicial : hoy;
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: primera,
      lastDate: hoy.add(const Duration(days: 365 * 3)),
      helpText: 'Fecha límite',
    );
    if (picked != null) setState(() => _fechaLimite = picked);
  }

  Task _borradorActual() => Task(
    id: widget.task?.id ?? 'borrador',
    titulo: _titulo.text,
    fechaLimite: _fechaLimite,
    horasEstimadas: _horas,
    categoria: _categoria,
    impacto: _impacto,
    urgencia: _urgencia,
    ansiedad: _ansiedad,
  );

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppState>();

    if (_editando) {
      app.updateTask(
        widget.task!.copyWith(
          titulo: _titulo.text.trim(),
          descripcion: _descripcion.text.trim(),
          fechaLimite: _fechaLimite,
          clearFechaLimite: _fechaLimite == null,
          horasEstimadas: _horas,
          categoria: _categoria,
          impacto: _impacto,
          urgencia: _urgencia,
          ansiedad: _ansiedad,
          dependencias: _dependencias,
        ),
      );
    } else {
      app.addTask(
        titulo: _titulo.text.trim(),
        descripcion: _descripcion.text.trim(),
        fechaLimite: _fechaLimite,
        horasEstimadas: _horas,
        categoria: _categoria,
        impacto: _impacto,
        urgencia: _urgencia,
        ansiedad: _ansiedad,
        dependencias: _dependencias,
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FocoTheme.superficie,
        title: const Text('¿Eliminar tarea?'),
        content: Text('«${widget.task!.titulo}» se borrará para siempre.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FocoTheme.peligro),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<AppState>().deleteTask(widget.task!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // Posibles dependencias: cualquier otra tarea no completada.
    final posibles = app.tasks
        .where((t) => t.id != widget.task?.id && !t.completada)
        .toList();
    final nivel = PriorityEngine.score(_borradorActual()).nivel;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar tarea' : 'Nueva tarea'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _guardar,
              child: const Text('Guardar'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ≥ 1000 px: dos columnas (información | prioridad).
            // ≥ 600 px: una columna centrada. Menos: móvil.
            final columnas = constraints.maxWidth >= 1000;
            final amplio = constraints.maxWidth >= 600;
            final margen = amplio ? 24.0 : 16.0;

            final info = _tarjetaInformacion(amplio);
            final prioridad = _tarjetaPrioridad(
              amplio: amplio,
              columnas: columnas,
              nivel: nivel,
            );
            final dependencias = posibles.isEmpty
                ? null
                : _tarjetaDependencias(posibles, amplio);
            final acciones = _acciones();

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(margen, 8, margen, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: columnas ? 1200 : 680),
                  child: columnas
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  info,
                                  if (dependencias != null) ...[
                                    const SizedBox(height: 20),
                                    dependencias,
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  prioridad,
                                  const SizedBox(height: 20),
                                  ...acciones,
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            info,
                            const SizedBox(height: 16),
                            prioridad,
                            if (dependencias != null) ...[
                              const SizedBox(height: 16),
                              dependencias,
                            ],
                            const SizedBox(height: 24),
                            ...acciones,
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tarjetaInformacion(bool amplio) {
    return _Tarjeta(
      amplio: amplio,
      titulo: 'Información de la tarea',
      children: [
        _Campo(
          etiqueta: 'Título *',
          child: TextFormField(
            controller: _titulo,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: '¿Qué necesitas hacer?',
              counterText: '',
              suffixIcon: IconButton(
                tooltip: 'Dictar por voz',
                icon: const Icon(Icons.mic_none),
                onPressed: _dictar,
              ),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ponle un título' : null,
          ),
        ),
        const SizedBox(height: 16),
        _Campo(
          etiqueta: 'Descripción (opcional)',
          child: TextFormField(
            controller: _descripcion,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 5,
            maxLength: 5000,
            decoration: const InputDecoration(
              hintText: 'Añade más detalles…',
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Campo(
          etiqueta: 'Categoría',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TaskCategory.values.map((c) {
              final sel = c == _categoria;
              return ChoiceChip(
                selected: sel,
                label: Text(c.label),
                avatar: Icon(
                  c.icon,
                  size: 16,
                  color: sel ? Colors.white : c.color,
                ),
                showCheckmark: false,
                selectedColor: c.color.withValues(alpha: 0.6),
                onSelected: (_) => setState(() => _categoria = c),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Campo(etiqueta: 'Fecha límite', child: _campoFecha()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Campo(etiqueta: 'Tiempo estimado', child: _campoTiempo()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tarjetaPrioridad({
    required bool amplio,
    required bool columnas,
    required PriorityLevel nivel,
  }) {
    return _Tarjeta(
      amplio: amplio,
      titulo: 'Prioridad de la tarea',
      subtitulo: 'Evalúa esta tarea según impacto, urgencia y ansiedad.',
      children: [
        for (final (eje, valor, cambiar) in [
          (Eje.impacto, _impacto, (int v) => _impacto = v),
          (Eje.urgencia, _urgencia, (int v) => _urgencia = v),
          (Eje.ansiedad, _ansiedad, (int v) => _ansiedad = v),
        ])
          _EjeSelector(
            eje: eje,
            valor: valor,
            amplio: columnas,
            onChanged: (v) => setState(() => cambiar(v)),
          ),
        const SizedBox(height: 6),
        PrioridadCard(nivel: nivel),
      ],
    );
  }

  Widget _tarjetaDependencias(List<Task> posibles, bool amplio) {
    return _Tarjeta(
      amplio: amplio,
      titulo: 'Depende de',
      subtitulo:
          'Si depende de otra tarea, se quedará bloqueada hasta cerrarla.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: posibles.map((t) {
            final sel = _dependencias.contains(t.id);
            return FilterChip(
              selected: sel,
              label: Text(t.titulo, overflow: TextOverflow.ellipsis),
              onSelected: (s) => setState(() {
                if (s) {
                  _dependencias.add(t.id);
                } else {
                  _dependencias.remove(t.id);
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _acciones() => [
    FilledButton(
      onPressed: _guardar,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      child: Text(_editando ? 'Guardar cambios' : 'Crear tarea'),
    ),
    if (_editando) ...[
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: _eliminar,
        style: TextButton.styleFrom(foregroundColor: FocoTheme.peligro),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Eliminar tarea'),
      ),
    ],
  ];

  Widget _campoFecha() {
    final fecha = _fechaLimite;
    return InkWell(
      onTap: _pickFecha,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.event_outlined, size: 20),
          prefixIconConstraints: _iconoCompacto,
          suffixIconConstraints: _iconoCompacto,
          suffixIcon: fecha == null
              ? const Icon(Icons.expand_more)
              : Tooltip(
                  message: 'Quitar fecha',
                  child: InkResponse(
                    radius: 18,
                    onTap: () => setState(() => _fechaLimite = null),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ),
        ),
        child: Text(
          fecha == null
              ? 'Sin fecha'
              : DateFormat(
                  fecha.year == DateTime.now().year ? 'EEE d MMM' : 'd MMM y',
                  'es',
                ).format(fecha),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: fecha == null ? Colors.white54 : null),
        ),
      ),
    );
  }

  Widget _campoTiempo() {
    final opciones = {..._opcionesHoras, _horas}.toList()..sort();
    return DropdownButtonFormField<double>(
      key: ValueKey(_horas),
      initialValue: _horas,
      isExpanded: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.timer_outlined, size: 20),
        prefixIconConstraints: _iconoCompacto,
      ),
      dropdownColor: FocoTheme.superficie2,
      borderRadius: BorderRadius.circular(14),
      items: opciones
          .map((h) => DropdownMenuItem(value: h, child: Text(formatHoras(h))))
          .toList(),
      onChanged: (h) {
        if (h != null) setState(() => _horas = h);
      },
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final bool amplio;
  final List<Widget> children;

  const _Tarjeta({
    required this.titulo,
    this.subtitulo,
    required this.amplio,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(amplio ? 24 : 18),
      decoration: BoxDecoration(
        color: FocoTheme.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitulo!,
              style: const TextStyle(fontSize: 12.5, color: Colors.white54),
            ),
          ],
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

/// Campo con su etiqueta encima.
class _Campo extends StatelessWidget {
  final String etiqueta;
  final Widget child;
  const _Campo({required this.etiqueta, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _EjeSelector extends StatelessWidget {
  final Eje eje;
  final int valor;
  final ValueChanged<int> onChanged;

  /// En escritorio la pregunta va en la misma línea y el nivel a la derecha
  /// de la escala.
  final bool amplio;

  const _EjeSelector({
    required this.eje,
    required this.valor,
    required this.onChanged,
    this.amplio = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = eje.color;
    final escala = _Escalones(
      valor: valor,
      color: color,
      etiqueta: eje.label,
      descripcionValor: '$valor de ${Task.ejeMax}, ${eje.nivel(valor)}',
      onChanged: onChanged,
    );
    final puntaje = Text(
      '$valor/${Task.ejeMax}',
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
    );

    if (amplio) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  eje.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    eje.pregunta,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.white54,
                    ),
                  ),
                ),
                puntaje,
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: escala),
                const SizedBox(width: 12),
                SizedBox(
                  width: 112,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Center(
                      child: NivelBadge(texto: eje.nivel(valor), color: color),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(eje.icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                eje.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: NivelBadge(texto: eje.nivel(valor), color: color),
                ),
              ),
              const SizedBox(width: 10),
              puntaje,
            ],
          ),
          const SizedBox(height: 2),
          Text(
            eje.pregunta,
            style: const TextStyle(fontSize: 12, color: Colors.white38),
          ),
          const SizedBox(height: 6),
          escala,
        ],
      ),
    );
  }
}

/// Selector de 1 a 5 con puntos unidos: ●───●───●───●───●
class _Escalones extends StatelessWidget {
  final int valor;
  final Color color;
  final String etiqueta;
  final String descripcionValor;
  final ValueChanged<int> onChanged;

  const _Escalones({
    required this.valor,
    required this.color,
    required this.etiqueta,
    required this.descripcionValor,
    required this.onChanged,
  });

  static const _margen = 16.0;
  static const _pasos = Task.ejeMax - Task.ejeMin;

  void _desde(double dx, double ancho) {
    final paso = (ancho - 2 * _margen) / _pasos;
    final i = ((dx - _margen) / paso).round().clamp(0, _pasos);
    final nuevo = Task.ejeMin + i;
    if (nuevo != valor) onChanged(nuevo);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = c.maxWidth;
        final paso = (ancho - 2 * _margen) / _pasos;
        return Semantics(
          slider: true,
          label: etiqueta,
          value: descripcionValor,
          increasedValue: valor < Task.ejeMax ? '${valor + 1}' : null,
          decreasedValue: valor > Task.ejeMin ? '${valor - 1}' : null,
          onIncrease: valor < Task.ejeMax ? () => onChanged(valor + 1) : null,
          onDecrease: valor > Task.ejeMin ? () => onChanged(valor - 1) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _desde(d.localPosition.dx, ancho),
            onHorizontalDragUpdate: (d) => _desde(d.localPosition.dx, ancho),
            child: SizedBox(
              height: 54,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _EscalonesPainter(
                        valor: valor,
                        color: color,
                        margen: _margen,
                      ),
                    ),
                  ),
                  for (var i = 0; i <= _pasos; i++)
                    Positioned(
                      left: _margen + i * paso - 14,
                      top: 34,
                      width: 28,
                      child: Text(
                        '${Task.ejeMin + i}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: Task.ejeMin + i == valor
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: Task.ejeMin + i == valor
                              ? color
                              : Colors.white38,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EscalonesPainter extends CustomPainter {
  final int valor;
  final Color color;
  final double margen;

  _EscalonesPainter({
    required this.valor,
    required this.color,
    required this.margen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const y = 16.0;
    const pasos = Task.ejeMax - Task.ejeMin;
    final paso = (size.width - 2 * margen) / pasos;
    double x(int i) => margen + i * paso;
    final sel = valor - Task.ejeMin;

    final pista = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(x(0), y),
      Offset(x(pasos), y),
      pista..color = Colors.white12,
    );
    if (sel > 0) {
      canvas.drawLine(Offset(x(0), y), Offset(x(sel), y), pista..color = color);
    }

    for (var i = 0; i <= pasos; i++) {
      final centro = Offset(x(i), y);
      if (i == sel) {
        canvas.drawCircle(
          centro,
          13,
          Paint()..color = color.withValues(alpha: 0.25),
        );
        canvas.drawCircle(centro, 9, Paint()..color = color);
        canvas.drawCircle(centro, 3.5, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(
          centro,
          6,
          Paint()..color = i < sel ? color : FocoTheme.superficie2,
        );
        canvas.drawCircle(
          centro,
          6,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = i < sel ? color : Colors.white30,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EscalonesPainter old) =>
      old.valor != valor || old.color != color || old.margen != margen;
}
