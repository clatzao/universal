import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal/core/json_store.dart';
import 'package:universal/core/theme.dart';
import 'package:universal/notes/note.dart';
import 'package:universal/notes/notes_page.dart';
import 'package:universal/notes/notes_store.dart';

final _t0 = DateTime(2026, 11, 3, 10);

Note _note({String title = '', String body = '', List<NoteItem>? items, NoteKind kind = NoteKind.nota}) =>
    Note(id: 'n', kind: kind, title: title, body: body, items: items, createdAt: _t0, updatedAt: _t0);

void main() {
  group('nota', () {
    test('vazia só sem título, texto e itens', () {
      expect(_note().isEmpty, isTrue);
      expect(_note(title: '  ').isEmpty, isTrue);
      expect(_note(body: 'x').isEmpty, isFalse);
      expect(
        _note(
          items: [NoteItem(id: '1', text: 'leite')],
        ).isEmpty,
        isFalse,
      );
    });

    test('busca ignora acentos e aceita várias palavras em qualquer ordem', () {
      final n = _note(
        title: 'Mercado',
        items: [NoteItem(id: '1', text: 'Pão de açúcar')],
        kind: NoteKind.lista,
      );
      expect(n.matches('acucar'), isTrue);
      expect(n.matches('PAO mercado'), isTrue);
      expect(n.matches('feijão'), isFalse);
      expect(n.matches('  '), isTrue);
    });

    test('nota vira lista e lista vira nota sem perder texto', () {
      var id = 0;
      final n = _note(body: 'leite\n\n  ovos \npão');
      n.convert(() => '${id++}');
      expect(n.kind, NoteKind.lista);
      expect(n.items.map((i) => i.text), ['leite', 'ovos', 'pão']);
      expect(n.body, isEmpty);
      n.convert(() => '${id++}');
      expect(n.kind, NoteKind.nota);
      expect(n.body, 'leite\novos\npão');
      expect(n.items, isEmpty);
    });

    test('texto para copiar', () {
      final l = _note(
        title: 'Feira',
        kind: NoteKind.lista,
        items: [
          NoteItem(id: '1', text: 'Banana', done: true),
          NoteItem(id: '2', text: 'Maçã'),
          NoteItem(id: '3'),
        ],
      );
      expect(l.toPlainText(), 'Feira\n[x] Banana\n[ ] Maçã');
      expect(_note(title: 'Ideia', body: 'Texto').toPlainText(), 'Ideia\nTexto');
    });

    test('JSON preserva tudo e tolera campos ausentes', () {
      final n = _note(
        title: 'T',
        items: [NoteItem(id: '1', text: 'a', done: true)],
        kind: NoteKind.lista,
      )..pinned = true;
      final back = Note.fromJson(n.toJson());
      expect(back.kind, NoteKind.lista);
      expect(back.pinned, isTrue);
      expect(back.items.single.done, isTrue);
      expect(back.updatedAt, _t0);
      expect(Note.fromJson({'id': 'x'}).kind, NoteKind.nota);
    });
  });

  group('store', () {
    late NotesStore store;

    setUp(() {
      JsonStore.directory = Directory.systemTemp.createTempSync('notes');
      store = NotesStore();
    });

    test('fixadas primeiro e depois as mais recentes', () async {
      final a = store.create(NoteKind.nota, now: DateTime(2026, 1, 1))..title = 'antiga';
      final b = store.create(NoteKind.nota, now: DateTime(2026, 2, 1))..title = 'nova';
      expect(store.sorted().first, b);
      await store.togglePin(a);
      expect(store.sorted().first, a);
      expect(store.pinned, [a]);
    });

    test('filtra por tipo e busca', () {
      store.create(NoteKind.nota).title = 'Viagem';
      store.create(NoteKind.lista).title = 'Compras';
      expect(store.sorted(kind: NoteKind.lista).single.title, 'Compras');
      expect(store.sorted(query: 'viagem').single.title, 'Viagem');
    });

    test('sair do editor descarta nota vazia e grava as outras', () async {
      final empty = store.create(NoteKind.nota);
      final full = store.create(NoteKind.nota)..body = 'texto';
      await store.finishEditing(empty);
      await store.finishEditing(full);
      expect(store.items, [full]);
      final again = NotesStore();
      await again.load();
      expect(again.items.single.body, 'texto');
    });

    test('excluir e desfazer', () async {
      final n = store.create(NoteKind.nota)..title = 'x';
      await store.remove(n);
      expect(store.items, isEmpty);
      await store.restore(n);
      await store.restore(n);
      expect(store.items, [n]);
    });
  });

  group('telas', () {
    late NotesStore store;

    setUp(() {
      JsonStore.directory = Directory.systemTemp.createTempSync('notesui');
      store = NotesStore();
    });

    Future<void> pump(WidgetTester tester, Widget home) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(theme: AppTheme.dark(), home: home),
        ),
      );
      await tester.pump();
    }

    testWidgets('lista: adicionar, marcar, limpar concluídos', (tester) async {
      final n = store.create(NoteKind.lista);
      await pump(tester, NoteEditorPage(noteId: n.id));
      await tester.enterText(find.widgetWithText(TextField, 'Adicionar item'), 'Leite');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(n.items.single.text, 'Leite');
      await tester.enterText(find.widgetWithText(TextField, 'Adicionar item'), 'Ovos');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(n.pending.length, 2);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(n.completed.single.text, 'Leite');
      expect(find.text('Concluídos (1)'), findsOneWidget);

      await tester.tap(find.byTooltip('Apagar concluídos'));
      await tester.pump();
      expect(n.items.single.text, 'Ovos');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('editar nota altera o conteúdo', (tester) async {
      final n = store.create(NoteKind.nota);
      await pump(tester, NoteEditorPage(noteId: n.id));
      await tester.enterText(find.widgetWithText(TextField, 'Título'), 'Ideia');
      await tester.enterText(find.widgetWithText(TextField, 'Escreva aqui'), 'Corpo');
      await tester.pump();
      expect(n.title, 'Ideia');
      expect(n.body, 'Corpo');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('página lista, busca e abre a nota', (tester) async {
      store.create(NoteKind.nota)
        ..title = 'Ideia do app'
        ..body = 'Corpo da ideia';
      store.create(NoteKind.lista)
        ..title = 'Mercado'
        ..items = [NoteItem(id: '1', text: 'Leite'), NoteItem(id: '2', text: 'Ovos', done: true)];
      await pump(tester, const NotesPage());
      expect(find.text('Ideia do app'), findsOneWidget);
      expect(find.text('1 de 2 concluídos'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Buscar'), 'mercado');
      await tester.pump();
      expect(find.text('Ideia do app'), findsNothing);
      expect(find.text('Mercado'), findsOneWidget);

      await tester.tap(find.text('Mercado'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(NoteEditorPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
