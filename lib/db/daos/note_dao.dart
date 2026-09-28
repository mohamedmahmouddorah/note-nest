import 'package:floor/floor.dart';
import '../entities/note.dart';

@dao
abstract class NoteDao {
  // DESC sorting biggest id first (newest note on top)
  @Query('SELECT * FROM Notes ORDER BY id DESC')
  Future<List<Note>> findAllNotes();

  @Query('SELECT * FROM Notes ORDER BY id DESC')
  Stream<List<Note>> watchAllNotes();

  @insert
  Future<void> insertNote(Note note);

  @update
  Future<void> updateNote(Note note);
  
  @Query('UPDATE Notes SET address = :address WHERE id = :id')
  Future<void> updateAddress(int id, String address);

  @delete
  Future<void> deleteNote(Note note);

  @Query('DELETE FROM Notes')
  Future<void> deleteAllNotes();
}
