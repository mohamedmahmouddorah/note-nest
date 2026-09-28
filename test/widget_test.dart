import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:note_nest/db/note_database.dart';
import 'package:note_nest/main.dart';
import 'package:note_nest/repositories/note_repository.dart';

late NoteDatabase database;

void main() {
  setUpAll(() async {
    database = await $FloorNoteDatabase.databaseBuilder('Notes.db').build();
  });

  tearDownAll(() async {
    await database.close();
  });

  testWidgets('NoteNest app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(NoteApp(repository: NoteRepository(database)));

    expect(find.text('My Notes'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
