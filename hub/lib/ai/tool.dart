import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart' hide Tool;
import '../services/database.dart';

const taskStatuses = [
  'open', 'approved', 'building', 'built',
  'review', 'testing', 'tested', 'reopened', 'closed',
];

class Tool {
  final String name;
  final String description;
  final Map<String, dynamic> inputJsonSchema;
  final Future<String> Function(Map<String, dynamic> args) execute;

  const Tool({
    required this.name,
    required this.description,
    required this.inputJsonSchema,
    required this.execute,
  });

  ToolSpec get spec => ToolSpec(
    name: name,
    description: description,
    inputJsonSchema: inputJsonSchema,
  );
}

final createTaskTool = Tool(
  name: 'create_task',
  description: 'Crea una nueva tarea de desarrollo en la base de datos',
  inputJsonSchema: {
    'type': 'object',
    'properties': {
      'title': {'type': 'string', 'description': 'Título de la tarea'},
      'description': {'type': 'string', 'description': 'Descripción detallada'},
    },
    'required': ['title'],
  },
  execute: (args) async {
    args['status'] = 'open';
    final id = await databaseService.create('tasks', args);
    return 'Tarea creada correctamente con id: $id. Usá este id como task_id para criterios.';
  },
);

final updateTaskTool = Tool(
  name: 'update_task',
  description: 'Actualiza una tarea existente (solo si está en open o reopened)',
  inputJsonSchema: {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'ID de la tarea'},
      'title': {'type': 'string', 'description': 'Nuevo título'},
      'description': {'type': 'string', 'description': 'Nueva descripción'},
      'status': {
        'type': 'string',
        'description': 'Nuevo estado: open/reopened',
      },
    },
    'required': ['id'],
  },
  execute: (args) async {
    final id = args['id'] as String;
    final existing = await databaseService.read('tasks', {'id': id});
    if (existing == null) return 'Error: tarea no encontrada';
    final currentStatus = existing['status'] as String?;
    if (currentStatus != 'open' && currentStatus != 'reopened') {
      return 'Error: solo se pueden modificar tareas en estado "open" o "reopened" (actual: "$currentStatus")';
    }
    final data = Map<String, dynamic>.from(args)..remove('id');
    await databaseService.update('tasks', {'id': id}, data);
    return 'Tarea actualizada correctamente';
  },
);

final listTasksTool = Tool(
  name: 'list_tasks',
  description: 'Lista todas las tareas de desarrollo guardadas',
  inputJsonSchema: {
    'type': 'object',
    'properties': {
      'status': {'type': 'string', 'description': 'Filtrar por estado'},
    },
  },
  execute: (args) async {
    final filter = <String, dynamic>{};
    if (args.containsKey('status')) filter['status'] = args['status'];
    final tasks = await databaseService.read('tasks', filter, many: true) as List;
    if (tasks.isEmpty) return 'No hay tareas guardadas';
    return tasks.map((t) => '- ${t['title']} (id: ${t['id']}) [${t['status'] ?? "open"}]').join('\n');
  },
);

final deleteTaskTool = Tool(
  name: 'delete_task',
  description: 'Elimina una tarea por su id',
  inputJsonSchema: {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'ID de la tarea'},
    },
    'required': ['id'],
  },
  execute: (args) async {
    await databaseService.delete('tasks', {'id': args['id']});
    return 'Tarea eliminada correctamente';
  },
);

final createCriteriaTool = Tool(
  name: 'create_criteria',
  description: 'Crea un criterio de aceptación para una tarea',
  inputJsonSchema: {
    'type': 'object',
    'properties': {
      'task_id': {'type': 'string', 'description': 'ID de la tarea'},
      'description': {'type': 'string', 'description': 'Descripción del criterio de aceptación'},
    },
    'required': ['task_id', 'description'],
  },
  execute: (args) async {
    debugPrint('[CRITERIA] ===== create_criteria =====');
    debugPrint('[CRITERIA] args received: $args');
    debugPrint('[CRITERIA] task_id: ${args["task_id"]}');
    debugPrint('[CRITERIA] description: ${args["description"]}');
    debugPrint('[CRITERIA] all keys: ${args.keys}');
    args['status'] = 'pending';
    try {
      final id = await databaseService.create('criteria', args);
      debugPrint('[CRITERIA] created with id: $id');
      debugPrint('[CRITERIA] args after create: $args');
      debugPrint('[CRITERIA] ===== create_criteria OK =====');
      return 'Criterio de aceptación creado correctamente con id: $id';
    } catch (e, st) {
      debugPrint('[CRITERIA] ERROR: $e');
      debugPrint('[CRITERIA] stack: $st');
      debugPrint('[CRITERIA] ===== create_criteria FAIL =====');
      return 'Error al crear criterio: $e';
    }
  },
);

final updateCriteriaTool = Tool(
  name: 'update_criteria',
  description: 'Actualiza un criterio de aceptación',
  inputJsonSchema: {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'ID del criterio'},
      'description': {'type': 'string', 'description': 'Nueva descripción'},
      'status': {
        'type': 'string',
        'description': 'Estado del criterio',
        'enum': ['pending', 'passed', 'failed'],
      },
    },
    'required': ['id'],
  },
  execute: (args) async {
    final data = Map<String, dynamic>.from(args);
    await databaseService.update('criteria', {'id': data.remove('id')}, data);
    return 'Criterio de aceptación actualizado correctamente';
  },
);

final deleteCriteriaTool = Tool(
  name: 'delete_criteria',
  description: 'Elimina un criterio de aceptación por su id',
  inputJsonSchema: {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'ID del criterio'},
    },
    'required': ['id'],
  },
  execute: (args) async {
    await databaseService.delete('criteria', {'id': args['id']});
    return 'Criterio de aceptación eliminado correctamente';
  },
);

final listCriteriaTool = Tool(
  name: 'list_criteria',
  description: 'Lista los criterios de aceptación de una tarea',
  inputJsonSchema: {
    'type': 'object',
    'properties': {
      'task_id': {'type': 'string', 'description': 'ID de la tarea (opcional)'},
    },
  },
  execute: (args) async {
    final filter = <String, dynamic>{};
    if (args.containsKey('task_id')) filter['task_id'] = args['task_id'];
    final criteria = await databaseService.read('criteria', filter, many: true) as List;
    if (criteria.isEmpty) return 'No hay criterios de aceptación';
    return criteria.map((c) => '- ${c['description']} (id: ${c['id']}) [${c['status']}]').join('\n');
  },
);
