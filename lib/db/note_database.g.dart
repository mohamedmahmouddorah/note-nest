// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_database.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

abstract class $NoteDatabaseBuilderContract {
  /// Adds migrations to the builder.
  $NoteDatabaseBuilderContract addMigrations(List<Migration> migrations);

  /// Adds a database [Callback] to the builder.
  $NoteDatabaseBuilderContract addCallback(Callback callback);

  /// Creates the database and initializes it.
  Future<NoteDatabase> build();
}

// ignore: avoid_classes_with_only_static_members
class $FloorNoteDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $NoteDatabaseBuilderContract databaseBuilder(String name) =>
      _$NoteDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $NoteDatabaseBuilderContract inMemoryDatabaseBuilder() =>
      _$NoteDatabaseBuilder(null);
}

class _$NoteDatabaseBuilder implements $NoteDatabaseBuilderContract {
  _$NoteDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  @override
  $NoteDatabaseBuilderContract addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  @override
  $NoteDatabaseBuilderContract addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  @override
  Future<NoteDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$NoteDatabase();
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
    return database;
  }
}

class _$NoteDatabase extends NoteDatabase {
  _$NoteDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  NoteDao? _noteDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
            database, startVersion, endVersion, migrations);

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `Notes` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `content` TEXT NOT NULL, `latitude` REAL, `longitude` REAL, `address` TEXT, `createdAt` INTEGER NOT NULL, `updatedAt` INTEGER NOT NULL)');

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  NoteDao get noteDao {
    return _noteDaoInstance ??= _$NoteDao(database, changeListener);
  }
}

class _$NoteDao extends NoteDao {
  _$NoteDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database, changeListener),
        _noteInsertionAdapter = InsertionAdapter(
            database,
            'Notes',
            (Note item) => <String, Object?>{
                  'id': item.id,
                  'content': item.content,
                  'latitude': item.latitude,
                  'longitude': item.longitude,
                  'address': item.address,
                  'createdAt': item.createdAt,
                  'updatedAt': item.updatedAt
                },
            changeListener),
        _noteUpdateAdapter = UpdateAdapter(
            database,
            'Notes',
            ['id'],
            (Note item) => <String, Object?>{
                  'id': item.id,
                  'content': item.content,
                  'latitude': item.latitude,
                  'longitude': item.longitude,
                  'address': item.address,
                  'createdAt': item.createdAt,
                  'updatedAt': item.updatedAt
                },
            changeListener),
        _noteDeletionAdapter = DeletionAdapter(
            database,
            'Notes',
            ['id'],
            (Note item) => <String, Object?>{
                  'id': item.id,
                  'content': item.content,
                  'latitude': item.latitude,
                  'longitude': item.longitude,
                  'address': item.address,
                  'createdAt': item.createdAt,
                  'updatedAt': item.updatedAt
                },
            changeListener);

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Note> _noteInsertionAdapter;

  final UpdateAdapter<Note> _noteUpdateAdapter;

  final DeletionAdapter<Note> _noteDeletionAdapter;

  @override
  Future<List<Note>> findAllNotes() async {
    return _queryAdapter.queryList('SELECT * FROM Notes ORDER BY id DESC',
        mapper: (Map<String, Object?> row) => Note(
            id: row['id'] as int?,
            content: row['content'] as String,
            latitude: row['latitude'] as double?,
            longitude: row['longitude'] as double?,
            address: row['address'] as String?,
            createdAt: row['createdAt'] as int,
            updatedAt: row['updatedAt'] as int));
  }

  @override
  Stream<List<Note>> watchAllNotes() {
    return _queryAdapter.queryListStream('SELECT * FROM Notes ORDER BY id DESC',
        mapper: (Map<String, Object?> row) => Note(
            id: row['id'] as int?,
            content: row['content'] as String,
            latitude: row['latitude'] as double?,
            longitude: row['longitude'] as double?,
            address: row['address'] as String?,
            createdAt: row['createdAt'] as int,
            updatedAt: row['updatedAt'] as int),
        queryableName: 'Notes',
        isView: false);
  }

  @override
  Future<void> updateAddress(
    int id,
    String address,
  ) async {
    await _queryAdapter.queryNoReturn(
        'UPDATE Notes SET address = ?2 WHERE id = ?1',
        arguments: [id, address]);
  }

  @override
  Future<void> deleteAllNotes() async {
    await _queryAdapter.queryNoReturn('DELETE FROM Notes');
  }

  @override
  Future<void> insertNote(Note note) async {
    await _noteInsertionAdapter.insert(note, OnConflictStrategy.abort);
  }

  @override
  Future<void> updateNote(Note note) async {
    await _noteUpdateAdapter.update(note, OnConflictStrategy.abort);
  }

  @override
  Future<void> deleteNote(Note note) async {
    await _noteDeletionAdapter.delete(note);
  }
}
