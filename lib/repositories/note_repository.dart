import '../db/daos/note_dao.dart';
import '../db/entities/note.dart';
import '../db/note_database.dart';

class NoteRepository {
  final NoteDatabase _database;
  const NoteRepository(this._database);

  NoteDao get _dao => _database.noteDao;

  static int _nowMillis() => DateTime.now().millisecondsSinceEpoch;

  Stream<List<Note>> watchAllNotes() => _dao.watchAllNotes();

  Future<void> addNote(Note note) {
    final now = _nowMillis();
    return _dao.insertNote(note.copyWith(createdAt: now, updatedAt: now));
  }

  Future<void> updateNote(Note note) =>
      _dao.updateNote(note.copyWith(updatedAt: _nowMillis()));

  Future<void> updateAddress(int id, String address) =>
      _dao.updateAddress(id, address);

  Future<void> deleteNote(Note note) => _dao.deleteNote(note);

  Future<void> deleteAllNotes() => _dao.deleteAllNotes();
  
  Future<void> restoreNote(Note note) => _dao.insertNote(note);
}
