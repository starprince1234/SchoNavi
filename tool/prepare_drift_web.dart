import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final packageConfig = File('.dart_tool/package_config.json');
  if (!packageConfig.existsSync()) {
    stderr.writeln(
      'Missing .dart_tool/package_config.json. Run flutter pub get first.',
    );
    exitCode = 2;
    return;
  }

  final config = jsonDecode(await packageConfig.readAsString());
  final packages = (config['packages'] as List<dynamic>).whereType<Map>();
  final sqlite = packages.cast<Map<dynamic, dynamic>?>().firstWhere(
    (entry) => entry?['name'] == 'sqlite3',
    orElse: () => null,
  );
  if (sqlite == null) {
    stderr.writeln(
      'The sqlite3 package is not present in package_config.json.',
    );
    exitCode = 2;
    return;
  }

  final rootUri = Uri.parse(sqlite['rootUri'] as String);
  final sqliteRoot = Directory.fromUri(
    packageConfig.parent.uri.resolveUri(rootUri),
  );
  final wasmCandidates = await sqliteRoot
      .list(recursive: true, followLinks: false)
      .where((entity) => entity is File && entity.path.endsWith('sqlite3.wasm'))
      .cast<File>()
      .toList();
  if (wasmCandidates.isEmpty) {
    stderr.writeln('sqlite3.wasm was not found below ${sqliteRoot.path}.');
    exitCode = 2;
    return;
  }

  final compile = await Process.run(Platform.resolvedExecutable, const [
    'compile',
    'js',
    '-O4',
    'tool/drift_worker.dart',
    '-o',
    'web/drift_worker.dart.js',
  ], runInShell: false);
  stdout.write(compile.stdout);
  stderr.write(compile.stderr);
  if (compile.exitCode != 0) {
    exitCode = compile.exitCode;
    return;
  }

  await wasmCandidates.first.copy('web/sqlite3.wasm');
  stdout.writeln('Prepared web/drift_worker.dart.js and web/sqlite3.wasm.');
}
