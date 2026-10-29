import 'package:flutter/material.dart';

import 'recurrence.dart';

enum Category {
  pessoal('Pessoal', Icons.person, Colors.indigo),
  saude('Saúde', Icons.favorite, Colors.red),
  contas('Contas', Icons.receipt_long, Colors.green),
  casa('Casa', Icons.home, Colors.orange),
  trabalho('Trabalho', Icons.work, Colors.blueGrey),
  estudos('Estudos', Icons.school, Colors.purple);

  final String label;
  final IconData icon;
  final Color color;

  const Category(this.label, this.icon, this.color);

  String get channelId => 'cat_$name';
  String get sound => 'som_$name';

  static Category of(String? name) => Category.values.firstWhere((c) => c.name == name, orElse: () => Category.pessoal);
}

class Reminder {
  final String id;

  /// Base dos IDs de notificação (nid*100 + slot).
  final int nid;
  String title;
  String notes;
  Category category;
  Recurrence rec;
  bool enabled;

  /// Alarme em tela cheia.
  bool alarm;

  /// Insistência: repetir a cada X min até N vezes.
  int insistEveryMin;
  int insistMax;

  final DateTime createdAt;
  DateTime? lastCompleted;
  DateTime? doneUntil;
  DateTime? snoozeUntil;

  /// Disparos de lembretes por lugar/condição.
  DateTime? lastTriggered;
  bool? inside;

  Reminder({
    required this.id,
    required this.nid,
    required this.title,
    this.notes = '',
    this.category = Category.pessoal,
    required this.rec,
    this.enabled = true,
    this.alarm = false,
    this.insistEveryMin = 0,
    this.insistMax = 0,
    required this.createdAt,
    this.lastCompleted,
    this.doneUntil,
    this.snoozeUntil,
    this.lastTriggered,
    this.inside,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nid': nid,
        'title': title,
        'notes': notes,
        'category': category.name,
        'rec': rec.toJson(),
        'enabled': enabled,
        'alarm': alarm,
        'insistEveryMin': insistEveryMin,
        'insistMax': insistMax,
        'createdAt': createdAt.toIso8601String(),
        'lastCompleted': lastCompleted?.toIso8601String(),
        'doneUntil': doneUntil?.toIso8601String(),
        'snoozeUntil': snoozeUntil?.toIso8601String(),
        'lastTriggered': lastTriggered?.toIso8601String(),
        'inside': inside,
      };

  factory Reminder.fromJson(Map<String, dynamic> j) {
    DateTime? dt(String k) => j[k] == null ? null : DateTime.parse(j[k] as String);
    return Reminder(
      id: j['id'] as String,
      nid: j['nid'] as int,
      title: (j['title'] as String?) ?? '',
      notes: (j['notes'] as String?) ?? '',
      category: Category.of(j['category'] as String?),
      rec: Recurrence.fromJson((j['rec'] as Map).cast<String, dynamic>()),
      enabled: (j['enabled'] as bool?) ?? true,
      alarm: (j['alarm'] as bool?) ?? false,
      insistEveryMin: (j['insistEveryMin'] as int?) ?? 0,
      insistMax: (j['insistMax'] as int?) ?? 0,
      createdAt: dt('createdAt') ?? DateTime.now(),
      lastCompleted: dt('lastCompleted'),
      doneUntil: dt('doneUntil'),
      snoozeUntil: dt('snoozeUntil'),
      lastTriggered: dt('lastTriggered'),
      inside: j['inside'] as bool?,
    );
  }
}
