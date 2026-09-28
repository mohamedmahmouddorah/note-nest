import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db/note_database.dart';
import 'pages/home_page.dart';
import 'repositories/note_repository.dart';

const _dbFileName = 'Notes.db';
const _dbAssetPath = 'assets/databases/$_dbFileName';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }

  final database = await _initDatabase();
  runApp(NoteApp(repository: NoteRepository(database)));
}

Future<NoteDatabase> _initDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, _dbFileName);

  await _copySeedDatabase(path);

  return $FloorNoteDatabase.databaseBuilder(path).build();
}

Future<void> _copySeedDatabase(String path) async {
  if (await File(path).exists()) return;

  try {
    final data = await rootBundle.load(_dbAssetPath);
    final tmp = File('$path.tmp');
    await tmp.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    await tmp.rename(path);
  } catch (e) {
    debugPrint('Error copying asset database: $e');
  }
}

class NoteApp extends StatelessWidget {
  final NoteRepository repository;
  const NoteApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NoteNest',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F4494)),
        useMaterial3: true,
      ),
      home: HomePage(repository: repository),
    );
  }
}
