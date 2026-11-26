import 'dart:convert';
import 'dart:io';

import '../models/completion_record.dart';

abstract interface class CompletionStore {
  Future<List<CompletionRecord>> readAll();
  Future<void> write(CompletionRecord record);
  Future<void> remove(int id);
}

class FileCompletionStore implements CompletionStore {
  FileCompletionStore(
    Future<Directory> Function() applicationDirectory, {
    required String scope,
  }) : _directory = _openDirectory(applicationDirectory, scope);

  final Future<Directory> _directory;

  static Future<Directory> _openDirectory(
    Future<Directory> Function() applicationDirectory,
    String scope,
  ) async {
    final location = await applicationDirectory();
    final namespace = base64Url.encode(utf8.encode(scope));
    return Directory(
      '${location.path}/completions/$namespace',
    ).create(recursive: true);
  }

  @override
  Future<List<CompletionRecord>> readAll() async {
    final directory = await _directory;
    final records = <CompletionRecord>[];
    await for (final entry in directory.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      final json =
          jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
      records.add(CompletionRecord.fromJson(json));
    }
    return records;
  }

  @override
  Future<void> write(CompletionRecord record) async {
    final file = await _file(record.id);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(record.toJson()), flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<void> remove(int id) async {
    final file = await _file(id);
    await file.delete();
  }

  Future<File> _file(int id) async {
    final directory = await _directory;
    return File('${directory.path}/$id.json');
  }
}
