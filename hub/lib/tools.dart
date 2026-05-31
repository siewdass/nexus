import 'dart:io';

class FileTools {
  final String workspace;

  FileTools(this.workspace);

  /// If [p] is an absolute path under [workspace], return the relative part;
  /// otherwise return [p] as-is.
  String _rel(String p) =>
      p.startsWith(workspace) ? p.substring(workspace.length + 1) : p;

  String read(String path) {
    final file = File('$workspace/${_rel(path)}');
    if (!file.existsSync()) return 'Error: $path not found';
    return file.readAsStringSync();
  }

  String write(String path, String content) {
    final file = File('$workspace/${_rel(path)}');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    return 'Saved: ${file.path}';
  }

  String listDir([String path = '']) {
    final normalized = _rel(path);
    final dir =
        Directory(normalized.isEmpty ? workspace : '$workspace/$normalized');
    if (!dir.existsSync()) return 'Error: $path not found';
    final items = dir.listSync().map((e) => e.path.split('/').last).toList();
    return items.isEmpty ? '(empty)' : items.join('\n');
  }

  String delete(String path) {
    final normalized = _rel(path);
    final entity = File('$workspace/$normalized');
    if (!entity.existsSync()) {
      final dir = Directory('$workspace/$normalized');
      if (!dir.existsSync()) return 'Error: $path not found';
      dir.deleteSync(recursive: true);
      return 'Deleted: ${dir.path}';
    }
    entity.deleteSync();
    return 'Deleted: ${entity.path}';
  }
}
