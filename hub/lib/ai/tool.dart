import 'package:langchain/langchain.dart' hide Tool;
import '../services/database.dart';

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
      'status': {
        'type': 'string',
        'description': 'Estado (pending/in_progress/done)',
        'default': 'pending',
      },
    },
    'required': ['title'],
  },
  execute: (args) async {
    await databaseService.create('tasks', args);
    return 'Tarea creada correctamente';
  },
);

final updateTaskTool = Tool(
  name: 'update_task',
  description: 'Actualiza una tarea existente por su id',
  inputJsonSchema: {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'ID de la tarea'},
      'title': {'type': 'string', 'description': 'Nuevo título'},
      'description': {'type': 'string', 'description': 'Nueva descripción'},
      'status': {'type': 'string', 'description': 'Nuevo estado'},
    },
    'required': ['id'],
  },
  execute: (args) async {
    final id = args['id'] as String;
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
    return tasks.map((t) => '- ${t['title']} (${t['id']})').join('\n');
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
