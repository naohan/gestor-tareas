import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';
import '../models/task.dart';
import 'foco_repository.dart';

/// Persistencia local con shared_preferences (JSON). Es el modo por defecto:
/// la app funciona completa sin red ni cuenta.
///
/// [namespace] separa los datos de cada cuenta en el mismo dispositivo; vacío
/// es el espacio del modo sin cuenta.
class LocalRepository implements FocoRepository {
  final String namespace;

  LocalRepository({this.namespace = ''});

  String get _tasksKey => '${namespace}foco_tasks_v2';

  /// Versión anterior, con los ejes en escala 0–10.
  static const _tasksKeyV1 = 'foco_tasks_v1';
  String get _projectsKey => '${namespace}foco_projects_v1';
  String get _achievementsKey => '${namespace}foco_unlocked_achievements_v1';

  @override
  bool get esRemoto => false;

  @override
  void dispose() {}

  @override
  Future<FocoSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();

    List<Task> tasks = const [];
    final rawTasks = prefs.getString(_tasksKey);
    if (rawTasks != null) {
      try {
        tasks = (jsonDecode(rawTasks) as List)
            .map((e) => Task.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    } else if (namespace.isEmpty) {
      final rawV1 = prefs.getString(_tasksKeyV1);
      if (rawV1 != null) {
        try {
          tasks = (jsonDecode(rawV1) as List)
              .map((e) => Task.fromJson(migrarEjesV1(e as Map<String, dynamic>)))
              .toList();
          await saveTasks(tasks);
          await prefs.remove(_tasksKeyV1);
        } catch (_) {}
      }
    }

    List<Project> projects = const [];
    final rawProjects = prefs.getString(_projectsKey);
    if (rawProjects != null) {
      try {
        projects = (jsonDecode(rawProjects) as List)
            .map((e) => Project.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final unlocked =
        prefs.getStringList(_achievementsKey)?.toSet() ?? <String>{};

    return FocoSnapshot(
      tasks: tasks,
      projects: projects,
      unlockedAchievements: unlocked,
    );
  }

  /// Convierte los ejes de la escala 0–10 a la escala 1–5.
  static Map<String, dynamic> migrarEjesV1(Map<String, dynamic> json) {
    int convertir(Object? v) =>
        (((v as num?)?.toDouble() ?? 5) / 2).round().clamp(Task.ejeMin, Task.ejeMax);
    return {
      ...json,
      'impacto': convertir(json['impacto']),
      'urgencia': convertir(json['urgencia']),
      'ansiedad': convertir(json['ansiedad']),
    };
  }

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _tasksKey, jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  @override
  Future<void> saveProjects(List<Project> projects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _projectsKey, jsonEncode(projects.map((p) => p.toJson()).toList()));
  }

  @override
  Future<void> saveUnlockedAchievements(Set<String> achievementIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_achievementsKey, achievementIds.toList());
  }

  Future<void> saveAll(FocoSnapshot snap) async {
    await saveTasks(snap.tasks);
    await saveProjects(snap.projects);
    await saveUnlockedAchievements(snap.unlockedAchievements);
  }
}
