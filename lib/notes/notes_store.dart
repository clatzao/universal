import 'package:flutter/foundation.dart';

import '../core/json_store.dart';
import 'note.dart';

class NotesStore extends ChangeNotifier {
  List<Note> items = [];

  static int _seq = 0;
  static String newId() => '${DateTime.now().microsecondsSinceEpoch}${_seq++}';

  Future<void> load() async {
    final j = await JsonStore.read('notes');
    items = [];
    if (j is List) {
      try {
        items = [for (final e in j) Note.fromJson((e as Map).cast<String, dynamic>())];
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> persist() => JsonStore.write('notes', [for (final n in items) n.toJson()]);

  /// Fixadas primeiro; dentro de cada grupo, as alteradas mais recentemente.
  List<Note> sorted({String query = '', NoteKind? kind}) {
    final list = items.where((n) => (kind == null || n.kind == kind) && n.matches(query)).toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  List<Note> get pinned => sorted().where((n) => n.pinned).toList();

  Note? byId(String id) => items.where((n) => n.id == id).firstOrNull;

  Note create(NoteKind kind, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final n = Note(id: newId(), kind: kind, createdAt: at, updatedAt: at);
    items.add(n);
    notifyListeners();
    return n;
  }

  /// Registra uma alteração. A gravação em disco fica a cargo de quem está editando.
  void touch(Note n, {DateTime? now}) {
    n.updatedAt = now ?? DateTime.now();
    notifyListeners();
  }

  Future<void> togglePin(Note n) async {
    n.pinned = !n.pinned;
    notifyListeners();
    await persist();
  }

  Future<void> remove(Note n) async {
    items.removeWhere((e) => e.id == n.id);
    notifyListeners();
    await persist();
  }

  Future<void> restore(Note n) async {
    if (byId(n.id) == null) items.add(n);
    notifyListeners();
    await persist();
  }

  /// Ao sair do editor: descarta notas que ficaram vazias e grava o resto.
  Future<void> finishEditing(Note n) async {
    if (n.isEmpty) items.removeWhere((e) => e.id == n.id);
    notifyListeners();
    await persist();
  }
}
