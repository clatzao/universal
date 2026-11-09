import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal/core/format.dart';
import 'package:universal/core/json_store.dart';
import 'package:universal/core/theme.dart';
import 'package:universal/finance/finance.dart';
import 'package:universal/finance/finance_store.dart';
import 'package:universal/habits/habit.dart';
import 'package:universal/news/rss.dart';
import 'package:universal/news/sources.dart';
import 'package:universal/notes/note.dart';
import 'package:universal/notes/notes_page.dart';
import 'package:universal/notes/notes_store.dart';
import 'package:universal/workout/workout.dart';
import 'package:universal/workout/workout_page.dart';
import 'package:universal/workout/workout_store.dart';

/// Gravar arquivo de verdade trava dentro do relógio falso dos testes de tela.
class _MemoryWorkouts extends WorkoutStore {
  @override
  Future<void> save() async => notifyListeners();
}

void main() {
  setUp(() => JsonStore.directory = Directory.systemTemp.createTempSync('etapa'));

  group('notícias', () {
    test('toda categoria tem fonte e nenhum id se repete', () {
      expect(newsSources.map((s) => s.id).toSet(), hasLength(newsSources.length));
      for (final t in Topic.values.where((t) => t != Topic.regiao)) {
        expect(newsSources.where((s) => s.topic == t), isNotEmpty, reason: t.label);
      }
    });

    test('estado sai da cidade escolhida, com ou sem acento', () {
      expect(regionalSource('Campinas, São Paulo, Brasil')!.url, contains('/sp/'));
      expect(regionalSource('Cuiabá, Mato Grosso, Brasil')!.url, contains('/mt/'));
      expect(regionalSource('Campo Grande, Mato Grosso do Sul, Brasil')!.url, contains('/ms/'));
      expect(regionalSource('Florianópolis, Santa Catarina, Brasil')!.name, 'ND+ Santa Catarina');
      expect(regionalSource('Brasília, Distrito Federal, Brasil')!.topic, Topic.regiao);
      expect(regionalSource('Sao Paulo')!.name, 'g1 São Paulo');
    });

    test('sem cidade ou fora do Brasil não há fonte regional', () {
      expect(regionalSource(null), isNull);
      expect(regionalSource('Lisboa, Lisboa, Portugal'), isNull);
      // Uma cidade com nome de estado não vale quando o estado vem depois.
      expect(regionalSource('Paraná, Rio Grande do Norte, Brasil')!.url, contains('/rn/'));
    });

    test('notícia guardada com categoria antiga continua abrindo', () {
      expect(Topic.of('brasil'), Topic.brasil);
      expect(Topic.of('inexistente'), Topic.brasil);
    });
  });

  group('metas de hábito', () {
    Habit habit() => Habit(id: 'h', nid: 1, name: 'Água', type: HabitType.agua, goal: 2, unit: 'l', quick: const [1]);
    final today = DateTime(2026, 11, 11); // quarta-feira

    test('semanas contam dias com meta, de segunda a domingo, sem passar de hoje', () {
      final h = habit();
      for (final d in [9, 10, 11, 4, 2]) {
        h.log[dayKey(DateTime(2026, 11, d))] = 2;
      }
      h.log[dayKey(DateTime(2026, 11, 3))] = 1;
      final weeks = h.weeksMet(today, 3);
      expect(weeks.map((w) => w.$1), [DateTime(2026, 10, 26), DateTime(2026, 11, 2), DateTime(2026, 11, 9)]);
      expect(weeks.map((w) => w.$2), [0, 2, 3]);
    });

    test('meses usam a fração dos dias, e o mês atual vai só até hoje', () {
      final h = habit();
      for (var d = 1; d <= 11; d++) {
        h.log[dayKey(DateTime(2026, 11, d))] = 2;
      }
      for (var d = 1; d <= 15; d++) {
        h.log[dayKey(DateTime(2026, 10, d))] = 3;
      }
      final months = h.monthsRate(today, 2);
      expect(months.first.$1, DateTime(2026, 10));
      expect(months.first.$2, closeTo(15 / 31, 1e-9));
      expect(months.last.$2, 1.0);
    });

    test('média diária inclui os dias sem registro', () {
      final h = habit()..log[dayKey(today)] = 3;
      expect(h.average(today, 30), closeTo(0.1, 1e-9));
    });
  });

  group('lista de compras', () {
    test('total soma preço vezes quantidade e ignora itens sem preço', () {
      final items = [
        NoteItem(id: 'a', text: 'Leite', price: 549, qty: 2),
        NoteItem(id: 'b', text: 'Pão', price: 800),
        NoteItem(id: 'c', text: 'Sal'),
      ];
      expect(shoppingTotal(items), 1898);
    });

    test('preço, quantidade e modo de compras sobrevivem a salvar e carregar', () {
      final n = Note(
        id: 'n',
        kind: NoteKind.lista,
        shopping: true,
        items: [NoteItem(id: 'a', text: 'Leite', price: 549, qty: 2)],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final back = Note.fromJson(n.toJson());
      expect(back.shopping, isTrue);
      expect(back.items.single.price, 549);
      expect(back.items.single.qty, 2);
      final plain = Note.fromJson(
        Note(id: 'x', kind: NoteKind.lista, createdAt: DateTime(2026), updatedAt: DateTime(2026)).toJson(),
      );
      expect(plain.shopping, isFalse);
    });

    testWidgets('lançar compra cria gasto em Mercado e desmarca os itens', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notes = NotesStore();
      final finance = FinanceStore()..accounts = [Account(id: 'a', name: 'Carteira', type: AccountType.carteira)];
      final note = notes.create(NoteKind.lista)
        ..title = 'Mercado da semana'
        ..shopping = true
        ..items = [
          NoteItem(id: '1', text: 'Leite', price: 549, qty: 2, done: true),
          NoteItem(id: '2', text: 'Café', price: 1500),
        ];
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: notes),
            ChangeNotifierProvider.value(value: finance),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: NoteEditorPage(noteId: note.id),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('No carrinho: ${brl(1098)}'), findsOneWidget);
      await tester.tap(find.text('Lançar compra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lançar'));
      await tester.pump();
      await tester.pumpAndSettle();
      final tx = finance.txs.single;
      expect(tx.amount, 1098);
      expect(tx.category, FinCategory.mercado);
      expect(tx.description, 'Mercado da semana');
      expect(note.items.every((i) => !i.done), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('treinos', () {
    final now = DateTime(2026, 11, 11, 18);

    Future<(WorkoutStore, Exercise, Exercise, Exercise)> setup() async {
      final s = WorkoutStore();
      await s.load();
      final run = await s.addExercise('Corrida', ExerciseKind.cardio);
      final push = await s.addExercise('Flexão', ExerciseKind.reps);
      final plank = await s.addExercise('Prancha', ExerciseKind.hold);
      return (s, run, push, plank);
    }

    WorkoutLog log(Exercise e, DateTime d, {double min = 0, double km = 0, int sets = 1, int reps = 0, int sec = 0}) =>
        WorkoutLog(
          id: WorkoutStore.newId(),
          exerciseId: e.id,
          date: d,
          minutes: min,
          km: km,
          sets: sets,
          reps: reps,
          seconds: sec,
        );

    test('ritmo e descrição do cardio', () {
      final l = WorkoutLog(id: 'x', exerciseId: 'e', date: now, minutes: 33, km: 6);
      expect(formatPace(l.pace!), '5:30/km');
      expect(describeLog(l, ExerciseKind.cardio), '33 min · 6 km · ritmo 5:30/km');
      expect(fmtNum(2.5), '2,5');
      expect(parseNum('2,5'), 2.5);
    });

    test('gráfico soma no dia, prancha usa o maior tempo, e o período corta os antigos', () async {
      final (s, run, push, plank) = await setup();
      await s.addLog(log(run, DateTime(2026, 11, 10, 7), min: 30, km: 5));
      await s.addLog(log(run, DateTime(2026, 11, 10, 19), min: 10, km: 2));
      await s.addLog(log(run, DateTime(2026, 6, 1), min: 20, km: 3));
      await s.addLog(log(plank, DateTime(2026, 11, 10), sets: 3, sec: 40));
      await s.addLog(log(plank, DateTime(2026, 11, 10), sets: 2, sec: 60));
      expect(s.series(run, TrendPeriod.d30, now), [(DateTime(2026, 11, 10), 7.0)]);
      expect(s.series(run, TrendPeriod.all, now), hasLength(2));
      expect(s.series(plank, TrendPeriod.d30, now).single.$2, 60);
      expect(s.best(run), 5);
      expect(s.best(push), 0);
    });

    test('resumo da semana compara com a anterior', () async {
      final (s, run, push, _) = await setup();
      await s.addLog(log(run, DateTime(2026, 11, 9), min: 30, km: 5));
      await s.addLog(log(push, DateTime(2026, 11, 9), sets: 3, reps: 12));
      await s.addLog(log(push, DateTime(2026, 11, 11), sets: 2, reps: 10));
      await s.addLog(log(run, DateTime(2026, 11, 8), min: 20));
      final w = s.week(now);
      expect((w.days, w.minutes, w.km, w.reps), (2, 30.0, 5.0, 56));
      expect(s.week(now, weeksAgo: 1).days, 1);
    });

    test('excluir exercício apaga os registros, e tudo volta depois de recarregar', () async {
      final (s, run, push, _) = await setup();
      await s.addLog(log(run, now, min: 30));
      await s.addLog(log(push, now, reps: 10));
      await s.addMeasure(Measurement(id: 'm', date: now, values: {'peso': 80, 'cintura': 90}));
      await s.removeExercise(run);
      await s.load();
      expect(s.exercises.map((e) => e.name), ['Flexão', 'Prancha']);
      expect(s.logs, hasLength(1));
      expect(s.latestMeasure('peso'), 80);
    });

    test('apagar uma medida mantém as outras do mesmo dia', () async {
      final (s, _, _, _) = await setup();
      final m = Measurement(id: 'm', date: now, values: {'peso': 80, 'cintura': 90});
      await s.addMeasure(m);
      await s.removeMeasure(m, 'peso');
      expect(s.measures.single.values, {'cintura': 90});
      await s.removeMeasure(m, 'cintura');
      expect(s.measures, isEmpty);
    });

    test('série de medidas em ordem de data', () async {
      final (s, _, _, _) = await setup();
      await s.addMeasure(Measurement(id: '2', date: DateTime(2026, 11, 10), values: {'peso': 79}));
      await s.addMeasure(Measurement(id: '1', date: DateTime(2026, 11, 1), values: {'peso': 81}));
      expect(s.measureSeries('peso', TrendPeriod.d30, now).map((p) => p.$2), [81, 79]);
    });

    testWidgets('aba: sugestão vira exercício, registro aparece e o gráfico pede mais dias', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = _MemoryWorkouts();
      await tester.pumpWidget(
        ChangeNotifierProvider<WorkoutStore>.value(
          value: store,
          child: MaterialApp(theme: AppTheme.dark(), home: const WorkoutPage()),
        ),
      );
      await tester.tap(find.text('Flexão'));
      await tester.pump();
      expect(store.exercises.single.name, 'Flexão');

      await tester.tap(find.byTooltip('Registrar Flexão'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Repetições por série'), '12');
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(store.logs.single.totalReps, 36);
      expect(find.textContaining('3 × 12 = 36'), findsOneWidget);
      expect(find.textContaining('1 dia(s) de treino'), findsOneWidget);

      await tester.tap(find.text('Flexão'));
      await tester.pumpAndSettle();
      expect(find.textContaining('pelo menos dois dias'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('detalhe desenha o gráfico com dois dias de registro', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final run = Exercise(id: 'run', name: 'Corrida', kind: ExerciseKind.cardio);
      final s = WorkoutStore()..exercises.add(run);
      final today = DateTime.now();
      s.logs.addAll([
        log(run, today.subtract(const Duration(days: 3)), min: 30, km: 5),
        log(run, today, min: 28, km: 5.5),
      ]);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: s,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: ExerciseDetailPage(exerciseId: run.id),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('+0,5 km'), findsOneWidget);
      expect(find.text('5,5 km'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
