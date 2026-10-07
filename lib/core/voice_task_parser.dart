import '../models/task.dart';

/// Lo que se pudo entender de una frase dictada. Los campos nulos no se
/// mencionaron y conservan su valor por defecto.
class VoiceTaskDraft {
  final String transcripcion;
  final String titulo;
  final DateTime? fechaLimite;
  final double? horasEstimadas;
  final TaskCategory? categoria;
  final int? impacto;
  final int? urgencia;
  final int? ansiedad;

  const VoiceTaskDraft({
    required this.transcripcion,
    required this.titulo,
    this.fechaLimite,
    this.horasEstimadas,
    this.categoria,
    this.impacto,
    this.urgencia,
    this.ansiedad,
  });

  bool get tieneTitulo => titulo.trim().isNotEmpty;
}

/// Interpreta frases en español como
/// "Terminar Geotón para el viernes, es urgente, me toma dos horas".
///
/// Funciona con reglas (sin IA): detecta fechas, duración, categoría y señales
/// de urgencia/impacto/ansiedad, las quita del texto y lo que queda es el título.
class VoiceTaskParser {
  static const _numeros = {
    'un': 1, 'una': 1, 'uno': 1, 'dos': 2, 'tres': 3, 'cuatro': 4,
    'cinco': 5, 'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9, 'diez': 10,
    'once': 11, 'doce': 12, 'quince': 15, 'veinte': 20, 'treinta': 30,
  };

  static const _diasSemana = {
    'lunes': DateTime.monday, 'martes': DateTime.tuesday,
    'miercoles': DateTime.wednesday, 'jueves': DateTime.thursday,
    'viernes': DateTime.friday, 'sabado': DateTime.saturday,
    'domingo': DateTime.sunday,
  };

  static const _meses = {
    'enero': 1, 'febrero': 2, 'marzo': 3, 'abril': 4, 'mayo': 5, 'junio': 6,
    'julio': 7, 'agosto': 8, 'septiembre': 9, 'setiembre': 9, 'octubre': 10,
    'noviembre': 11, 'diciembre': 12,
  };

  static const _categoriaPorNombre = {
    'trabajo': TaskCategory.trabajo, 'estudio': TaskCategory.estudio,
    'estudios': TaskCategory.estudio, 'personal': TaskCategory.personal,
    'salud': TaskCategory.salud, 'proyecto': TaskCategory.proyecto,
    'proyectos': TaskCategory.proyecto,
  };

  static final _categoriaPorPalabra = <TaskCategory, RegExp>{
    TaskCategory.salud: RegExp(
        r'\b(medico|doctor|doctora|dentista|gimnasio|gym|entrenar|correr|ejercicio|cita medica|terapia|pastillas)\b'),
    TaskCategory.estudio: RegExp(
        r'\b(estudiar|examen|parcial|curso|clase|universidad|tesis|leer|lectura|repasar|certificacion)\b'),
    TaskCategory.trabajo: RegExp(
        r'\b(reunion|cliente|clientes|oficina|jefe|jefa|informe|correo|email|presentacion|factura)\b'),
    TaskCategory.personal: RegExp(
        r'\b(comprar|supermercado|casa|familia|mama|papa|limpiar|pagar|cumpleanos|regalo)\b'),
    TaskCategory.proyecto: RegExp(r'\b(proyecto|propuesta|prototipo|lanzar|desplegar)\b'),
  };

  static const _num = r'(\d+|un|una|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|quince|veinte|treinta)';

  static VoiceTaskDraft parse(String texto, {DateTime? hoy}) {
    final ahora = hoy ?? DateTime.now();
    final base = DateTime(ahora.year, ahora.month, ahora.day);
    final original = texto.trim();
    final s = _Frase(original);

    // ---- Señales de urgencia / impacto / ansiedad (las negaciones primero) ----
    int? urgencia;
    if (s.quitar(r'\b(no es urgente|sin prisa|cuando pueda|no corre prisa)\b')) {
      urgencia = 1;
    } else if (s.quitar(
        r'\b(es )?(muy urgente|urgentisimo|urgente|urge|cuanto antes|lo antes posible|ya mismo)\b')) {
      urgencia = 5;
    }

    int? impacto;
    if (s.quitar(r'\b(no es importante|poco importante|no es prioritario)\b')) {
      impacto = 1;
    } else if (s.quitar(
        r'\b(es )?(muy importante|importantisimo|importantisima|crucial|clave|prioritario|prioritaria)\b')) {
      impacto = 5;
    } else if (s.quitar(r'\b(es )?importante\b')) {
      impacto = 4;
    }

    int? ansiedad;
    if (s.quitar(r'\b(no me preocupa|me da igual|estoy tranquila|estoy tranquilo)\b')) {
      ansiedad = 1;
    } else if (s.quitar(
        r'\b(me agobia|me estresa|me da ansiedad|me bloquea|me angustia|me abruma|me da miedo|me tiene bloqueada|me tiene bloqueado)\b')) {
      ansiedad = 5;
    } else if (s.quitar(r'\b(me preocupa|me inquieta|me pesa)\b')) {
      ansiedad = 4;
    }

    // ---- Duración ----
    double? horas;
    final conector = r'(?:(?:me |le )?(?:toma|tomara|lleva|llevara|tardo|tardare|durara|dura)\s+|durante\s+|de\s+|en\s+)?';
    final horaYMedia = s.buscar('$conector$_num horas? y media\\b');
    final horasNum = horaYMedia == null ? s.buscar('$conector$_num horas?\\b') : null;
    final mediaHora = s.buscar('$conector(media hora)\\b');
    final minutos = s.buscar('$conector$_num minutos?\\b');
    if (horaYMedia != null) {
      horas = (_numero(horaYMedia.group(1)!) ?? 1) + 0.5;
      s.quitarMatch(horaYMedia);
    } else if (horasNum != null) {
      horas = (_numero(horasNum.group(1)!) ?? 1).toDouble();
      s.quitarMatch(horasNum);
    } else if (mediaHora != null) {
      horas = 0.5;
      s.quitarMatch(mediaHora);
    } else if (minutos != null) {
      horas = (_numero(minutos.group(1)!) ?? 30) / 60;
      s.quitarMatch(minutos);
    }

    // ---- Fecha ----
    final prep = r'(?:(?:para|antes del?|hasta el|el|este|esta|la|para el|para la)\s+)?';
    DateTime? fecha;
    RegExpMatch? m;
    if ((m = s.buscar('${prep}pasado manana\\b')) != null) {
      fecha = base.add(const Duration(days: 2));
    } else if ((m = s.buscar('$prep(?<!la |por la )manana\\b')) != null) {
      fecha = base.add(const Duration(days: 1));
    } else if ((m = s.buscar('$prep(hoy|esta tarde|esta noche)\\b')) != null) {
      fecha = base;
    } else if ((m = s.buscar('$prep(?:en|dentro de) $_num (dias?|semanas?)\\b')) != null) {
      final n = _numero(m!.group(1)!) ?? 1;
      fecha = base.add(Duration(days: m.group(2)!.startsWith('semana') ? n * 7 : n));
    } else if ((m = s.buscar('$prep(?:la )?(?:proxima semana|semana que viene)\\b')) != null) {
      fecha = base.add(const Duration(days: 7));
    } else if ((m = s.buscar(
            '$prep(?:proximo |proxima )?(lunes|martes|miercoles|jueves|viernes|sabado|domingo)(?: que viene)?\\b')) !=
        null) {
      final objetivo = _diasSemana[m!.group(1)!]!;
      var delta = (objetivo - base.weekday) % 7;
      if (delta == 0) delta = 7;
      fecha = base.add(Duration(days: delta));
    } else if ((m = s.buscar(
            '$prep(\\d{1,2}) de (enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre)\\b')) !=
        null) {
      final dia = int.parse(m!.group(1)!);
      final mes = _meses[m.group(2)!]!;
      var candidata = DateTime(base.year, mes, dia);
      if (candidata.isBefore(base)) candidata = DateTime(base.year + 1, mes, dia);
      fecha = candidata;
    } else if ((m = s.buscar('(?:para el|antes del|hasta el|el) (\\d{1,2})\\b(?! horas?| minutos?)')) != null) {
      final dia = int.parse(m!.group(1)!);
      if (dia >= 1 && dia <= 31) {
        var candidata = DateTime(base.year, base.month, dia);
        if (candidata.isBefore(base)) candidata = DateTime(base.year, base.month + 1, dia);
        fecha = candidata;
      } else {
        m = null;
      }
    }
    if (m != null) s.quitarMatch(m);

    // ---- Categoría ----
    TaskCategory? categoria;
    final explicita = s.buscar(
        r'(?:en |de )?(?:la )?categoria (trabajo|estudios?|personal|salud|proyectos?)\b');
    if (explicita != null) {
      categoria = _categoriaPorNombre[explicita.group(1)!];
      s.quitarMatch(explicita);
    } else {
      for (final entry in _categoriaPorPalabra.entries) {
        if (entry.value.hasMatch(s.normalizada)) {
          categoria = entry.key;
          break;
        }
      }
    }

    // ---- Título: lo que queda, sin muletillas de inicio ----
    s.quitar(
        r'^\s*(?:(?:crear|crea|nueva|agregar|agrega|anadir|anade|anotar|anota|apuntar|apunta)\b)?\s*(?:una\s+)?(?:(?:tarea|recordatorio)\b\s*(?:(?:de|para)\s+|:)?)?\s*');
    s.quitar(r'^\s*(?:recuerdame|recordarme|tengo que|necesito|debo|hay que)\s+');

    return VoiceTaskDraft(
      transcripcion: original,
      titulo: _limpiarTitulo(s.texto),
      fechaLimite: fecha,
      horasEstimadas: horas,
      categoria: categoria,
      impacto: impacto,
      urgencia: urgencia,
      ansiedad: ansiedad,
    );
  }

  static int? _numero(String token) => int.tryParse(token) ?? _numeros[token];

  static String _limpiarTitulo(String texto) {
    final conectores = RegExp(
        r'^(?:[\s,.;:]+|(?:y|e|que|es|para|de|del|el|la|antes|pero)\b)+|(?:[\s,.;:]+|\b(?:y|e|que|es|para|de|del|el|la|antes|pero))+$',
        caseSensitive: false);
    var t = texto.replaceAll(RegExp(r'\s*,\s*(?:,\s*)+'), ', ');
    String anterior;
    do {
      anterior = t;
      t = t.replaceAll(conectores, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    } while (t != anterior);
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }
}

/// Texto original + versión normalizada (minúsculas, sin tildes) con los
/// mismos índices, para buscar en la normalizada y recortar en la original.
class _Frase {
  String texto;
  String normalizada;

  _Frase(String original)
      : texto = original,
        normalizada = _normalizar(original);

  static String _normalizar(String s) {
    const de = 'áéíóúüñÁÉÍÓÚÜÑ';
    const a = 'aeiouunAEIOUUN';
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      final i = de.indexOf(ch);
      buf.write(i == -1 ? ch : a[i]);
    }
    return buf.toString().toLowerCase();
  }

  RegExpMatch? buscar(String patron) => RegExp(patron).firstMatch(normalizada);

  bool quitar(String patron) {
    final m = buscar(patron);
    if (m == null) return false;
    quitarMatch(m);
    return true;
  }

  void quitarMatch(RegExpMatch m) {
    texto = '${texto.substring(0, m.start)} ${texto.substring(m.end)}';
    normalizada = '${normalizada.substring(0, m.start)} ${normalizada.substring(m.end)}';
  }
}
