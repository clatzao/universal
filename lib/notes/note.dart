import '../core/text_norm.dart';

enum NoteKind { nota, lista }

class NoteItem {
  final String id;
  String text;
  bool done;

  NoteItem({required this.id, this.text = '', this.done = false});

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'done': done};

  factory NoteItem.fromJson(Map<String, dynamic> j) =>
      NoteItem(id: j['id'] as String, text: j['text'] as String? ?? '', done: j['done'] as bool? ?? false);
}

class Note {
  final String id;
  NoteKind kind;
  String title;
  String body;
  List<NoteItem> items;
  bool pinned;
  final DateTime createdAt;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.kind,
    this.title = '',
    this.body = '',
    List<NoteItem>? items,
    this.pinned = false,
    required this.createdAt,
    required this.updatedAt,
  }) : items = items ?? [];

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty && items.every((i) => i.text.trim().isEmpty);

  List<NoteItem> get pending => items.where((i) => !i.done).toList();

  List<NoteItem> get completed => items.where((i) => i.done).toList();

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    return kind == NoteKind.lista ? 'Lista sem título' : 'Nota sem título';
  }

  /// Texto para copiar e compartilhar.
  String toPlainText() {
    final lines = <String>[if (title.trim().isNotEmpty) title.trim()];
    if (kind == NoteKind.nota) {
      if (body.trim().isNotEmpty) lines.add(body.trim());
    } else {
      for (final i in items) {
        if (i.text.trim().isNotEmpty) lines.add('${i.done ? '[x]' : '[ ]'} ${i.text.trim()}');
      }
    }
    return lines.join('\n');
  }

  /// Nota vira lista (uma linha por item) e lista vira nota (um item por linha).
  void convert(String Function() newId) {
    if (kind == NoteKind.nota) {
      items = [
        for (final line in body.split('\n'))
          if (line.trim().isNotEmpty) NoteItem(id: newId(), text: line.trim()),
      ];
      body = '';
      kind = NoteKind.lista;
    } else {
      body = items.where((i) => i.text.trim().isNotEmpty).map((i) => i.text.trim()).join('\n');
      items = [];
      kind = NoteKind.nota;
    }
  }

  bool matches(String query) {
    final q = normalizeKeepLength(query.trim());
    if (q.isEmpty) return true;
    final text = normalizeKeepLength('$title $body ${items.map((i) => i.text).join(' ')}');
    return q.split(RegExp(r'\s+')).every(text.contains);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'body': body,
    'items': [for (final i in items) i.toJson()],
    'pinned': pinned,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> j) {
    final created = DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now();
    return Note(
      id: j['id'] as String,
      kind: NoteKind.values.where((k) => k.name == j['kind']).firstOrNull ?? NoteKind.nota,
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      items: [for (final e in (j['items'] as List? ?? const [])) NoteItem.fromJson((e as Map).cast<String, dynamic>())],
      pinned: j['pinned'] as bool? ?? false,
      createdAt: created,
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? created,
    );
  }
}
