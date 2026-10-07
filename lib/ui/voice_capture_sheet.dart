import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/priority_engine.dart';
import '../core/voice_task_parser.dart';
import '../models/task.dart';
import '../services/voice_service.dart';
import '../theme.dart';
import 'widgets/priority_widgets.dart';

class VoiceCaptureResult {
  final VoiceTaskDraft draft;

  /// true: abrir el editor con lo entendido; false: guardar directamente.
  final bool editar;

  const VoiceCaptureResult(this.draft, {required this.editar});
}

/// Abre la hoja de dictado. Con [soloDictar] solo devuelve lo entendido para
/// rellenar un formulario (sin opción de guardar directamente).
Future<VoiceCaptureResult?> mostrarCapturaPorVoz(BuildContext context,
    {bool soloDictar = false}) {
  return showModalBottomSheet<VoiceCaptureResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: FocoTheme.superficie,
    constraints: const BoxConstraints(maxWidth: 640),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => VoiceCaptureSheet(soloDictar: soloDictar),
  );
}

/// Tarea provisional con lo dictado, para calcular la prioridad en vivo.
Task tareaDesdeBorrador(VoiceTaskDraft d) => Task(
      id: 'borrador',
      titulo: d.titulo,
      fechaLimite: d.fechaLimite,
      horasEstimadas: d.horasEstimadas ?? 1,
      categoria: d.categoria ?? TaskCategory.proyecto,
      impacto: d.impacto ?? 3,
      urgencia: d.urgencia ?? 3,
      ansiedad: d.ansiedad ?? 3,
    );

class VoiceCaptureSheet extends StatefulWidget {
  final bool soloDictar;
  const VoiceCaptureSheet({super.key, this.soloDictar = false});

  @override
  State<VoiceCaptureSheet> createState() => _VoiceCaptureSheetState();
}

class _VoiceCaptureSheetState extends State<VoiceCaptureSheet> {
  final _voz = VoiceService();
  final _texto = TextEditingController();

  @override
  void initState() {
    super.initState();
    _voz.addListener(_alCambiarVoz);
    WidgetsBinding.instance.addPostFrameCallback((_) => _voz.escuchar());
  }

  /// Solo se copia al campo cuando cambia lo dictado, para no pisar lo que
  /// la persona haya corregido a mano.
  String _ultimaTranscripcion = '';

  void _alCambiarVoz() {
    final t = _voz.transcripcion;
    if (t != _ultimaTranscripcion) {
      _ultimaTranscripcion = t;
      _texto.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _voz.removeListener(_alCambiarVoz);
    _voz.dispose();
    _texto.dispose();
    super.dispose();
  }

  Future<void> _alternarMicro() async {
    if (_voz.escuchando) {
      await _voz.detener();
    } else {
      await _voz.escuchar();
    }
  }

  void _terminar(VoiceTaskDraft d, {required bool editar}) {
    _voz.detener();
    Navigator.of(context).pop(VoiceCaptureResult(d, editar: editar));
  }

  @override
  Widget build(BuildContext context) {
    final draft = VoiceTaskParser.parse(_texto.text);
    final escuchando = _voz.escuchando;

    final String estado;
    if (escuchando) {
      estado = 'Te escucho…';
    } else if (_voz.error != null) {
      estado = _voz.error!;
    } else {
      estado = 'Toca el micrófono para hablar';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.soloDictar ? 'Dicta la tarea' : 'Dime tu tarea',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Ej. «Terminar Geotón para el viernes, es urgente, me toma dos horas»',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Center(
              child: _BotonMicro(
                escuchando: escuchando,
                onTap: _alternarMicro,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              estado,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _voz.error != null && !escuchando
                    ? FocoTheme.peligro
                    : Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _texto,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Lo que entendí',
                helperText: 'Puedes corregirlo o escribir la frase.',
                alignLabelWithHint: true,
              ),
            ),
            if (draft.tieneTitulo) ...[
              const SizedBox(height: 18),
              _VistaPrevia(draft: draft),
            ],
            const SizedBox(height: 20),
            if (widget.soloDictar)
              FilledButton.icon(
                onPressed: draft.tieneTitulo
                    ? () => _terminar(draft, editar: true)
                    : null,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                icon: const Icon(Icons.check),
                label: const Text('Usar en el formulario'),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: draft.tieneTitulo
                          ? () => _terminar(draft, editar: true)
                          : null,
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50)),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Revisar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: draft.tieneTitulo
                          ? () => _terminar(draft, editar: false)
                          : null,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50)),
                      icon: const Icon(Icons.check),
                      label: const Text('Guardar tarea'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _BotonMicro extends StatelessWidget {
  final bool escuchando;
  final VoidCallback onTap;
  const _BotonMicro({required this.escuchando, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = escuchando ? FocoTheme.peligro : FocoTheme.seed;
    return Semantics(
      button: true,
      label: escuchando ? 'Dejar de escuchar' : 'Empezar a dictar',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
                color: color.withValues(alpha: escuchando ? 0.9 : 0.4),
                width: escuchando ? 4 : 2),
          ),
          child: Icon(escuchando ? Icons.stop_rounded : Icons.mic,
              size: 40, color: color),
        ),
      ),
    );
  }
}

class _VistaPrevia extends StatelessWidget {
  final VoiceTaskDraft draft;
  const _VistaPrevia({required this.draft});

  @override
  Widget build(BuildContext context) {
    final nivel = PriorityEngine.score(tareaDesdeBorrador(draft)).nivel;
    final chips = <Widget>[
      if (draft.fechaLimite != null)
        _Dato(Icons.event,
            DateFormat("EEE d 'de' MMM", 'es').format(draft.fechaLimite!)),
      if (draft.horasEstimadas != null)
        _Dato(Icons.timer_outlined, formatHoras(draft.horasEstimadas!)),
      if (draft.categoria != null)
        _Dato(draft.categoria!.icon, draft.categoria!.label,
            color: draft.categoria!.color),
      if (draft.impacto != null)
        _Dato(Eje.impacto.icon, 'Impacto: ${Eje.impacto.nivel(draft.impacto!)}',
            color: Eje.impacto.color),
      if (draft.urgencia != null)
        _Dato(Eje.urgencia.icon, Eje.urgencia.nivel(draft.urgencia!),
            color: Eje.urgencia.color),
      if (draft.ansiedad != null)
        _Dato(Eje.ansiedad.icon, Eje.ansiedad.nivel(draft.ansiedad!),
            color: Eje.ansiedad.color),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FocoTheme.superficie2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(draft.titulo,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
          const SizedBox(height: 12),
          PrioridadCard(nivel: nivel, compacta: true),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color color;
  const _Dato(this.icon, this.texto, {this.color = Colors.white70});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(texto, style: TextStyle(fontSize: 12.5, color: color)),
        ],
      ),
    );
  }
}
