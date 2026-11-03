import '../core/text_norm.dart';
import 'rss.dart';

enum FollowKind { time, liga, esporte }

/// Time, liga ou esporte que pode ser seguido. [geSlug] liga ao feed próprio do time no ge.
class SportsTopic {
  final String id;
  final String label;
  final FollowKind kind;
  final List<String> aliases;
  final String? geSlug;

  const SportsTopic(this.id, this.label, this.kind, this.aliases, {this.geSlug});
}

const sportsCatalog = <SportsTopic>[
  SportsTopic('flamengo', 'Flamengo', FollowKind.time, ['flamengo', 'mengao'], geSlug: 'flamengo'),
  SportsTopic('palmeiras', 'Palmeiras', FollowKind.time, ['palmeiras', 'verdao'], geSlug: 'palmeiras'),
  SportsTopic('corinthians', 'Corinthians', FollowKind.time, ['corinthians', 'timao'], geSlug: 'corinthians'),
  SportsTopic('sao-paulo', 'São Paulo', FollowKind.time, ['sao paulo', 'tricolor paulista'], geSlug: 'sao-paulo'),
  SportsTopic('santos', 'Santos', FollowKind.time, ['santos', 'peixe'], geSlug: 'santos'),
  SportsTopic('vasco', 'Vasco', FollowKind.time, ['vasco'], geSlug: 'vasco'),
  SportsTopic('botafogo', 'Botafogo', FollowKind.time, ['botafogo'], geSlug: 'botafogo'),
  SportsTopic('fluminense', 'Fluminense', FollowKind.time, ['fluminense'], geSlug: 'fluminense'),
  SportsTopic('gremio', 'Grêmio', FollowKind.time, ['gremio'], geSlug: 'gremio'),
  SportsTopic('internacional', 'Internacional', FollowKind.time, [
    'colorado',
    'inter',
    'internacional-rs',
  ], geSlug: 'internacional'),
  SportsTopic('cruzeiro', 'Cruzeiro', FollowKind.time, ['cruzeiro'], geSlug: 'cruzeiro'),
  SportsTopic('atletico-mg', 'Atlético-MG', FollowKind.time, [
    'atletico-mg',
    'atletico mineiro',
    'galo',
  ], geSlug: 'atletico-mg'),
  SportsTopic('bahia', 'Bahia', FollowKind.time, ['bahia']),
  SportsTopic('vitoria', 'Vitória', FollowKind.time, ['vitoria-ba', 'ec vitoria', 'leao da barra']),
  SportsTopic('fortaleza', 'Fortaleza', FollowKind.time, ['fortaleza']),
  SportsTopic('ceara', 'Ceará', FollowKind.time, ['ceara']),
  SportsTopic('sport', 'Sport', FollowKind.time, ['sport recife', 'sport']),
  SportsTopic('athletico-pr', 'Athletico-PR', FollowKind.time, ['athletico', 'furacao']),
  SportsTopic('coritiba', 'Coritiba', FollowKind.time, ['coritiba']),
  SportsTopic('bragantino', 'Red Bull Bragantino', FollowKind.time, ['bragantino', 'massa bruta']),
  SportsTopic('chapecoense', 'Chapecoense', FollowKind.time, ['chapecoense']),
  SportsTopic('mirassol', 'Mirassol', FollowKind.time, ['mirassol']),
  SportsTopic('remo', 'Remo', FollowKind.time, ['remo']),
  SportsTopic('juventude', 'Juventude', FollowKind.time, ['juventude']),
  SportsTopic('brasileirao', 'Brasileirão', FollowKind.liga, [
    'brasileirao',
    'campeonato brasileiro',
    'serie a do brasileiro',
  ]),
  SportsTopic('serie-b', 'Série B', FollowKind.liga, ['serie b']),
  SportsTopic('copa-do-brasil', 'Copa do Brasil', FollowKind.liga, ['copa do brasil']),
  SportsTopic('libertadores', 'Libertadores', FollowKind.liga, ['libertadores']),
  SportsTopic('sul-americana', 'Sul-Americana', FollowKind.liga, ['sul-americana', 'sul americana']),
  SportsTopic('selecao', 'Seleção Brasileira', FollowKind.liga, ['selecao brasileira', 'canarinho']),
  SportsTopic('copa-do-mundo', 'Copa do Mundo', FollowKind.liga, ['copa do mundo']),
  SportsTopic('champions', 'Champions League', FollowKind.liga, ['champions']),
  SportsTopic('premier', 'Premier League', FollowKind.liga, ['premier league', 'campeonato ingles']),
  SportsTopic('laliga', 'La Liga', FollowKind.liga, ['la liga', 'laliga', 'campeonato espanhol']),
  SportsTopic('serie-a-ita', 'Italiano', FollowKind.liga, ['campeonato italiano', 'serie a italiana', 'calcio']),
  SportsTopic('bundesliga', 'Bundesliga', FollowKind.liga, ['bundesliga', 'campeonato alemao']),
  SportsTopic('f1', 'Fórmula 1', FollowKind.esporte, ['formula 1', 'f1']),
  SportsTopic('nba', 'NBA', FollowKind.esporte, ['nba']),
  SportsTopic('nfl', 'NFL', FollowKind.esporte, ['nfl']),
  SportsTopic('ufc', 'UFC e MMA', FollowKind.esporte, ['ufc', 'mma']),
  SportsTopic('tenis', 'Tênis', FollowKind.esporte, ['tenis', 'atp', 'wta', 'roland garros', 'wimbledon']),
  SportsTopic('volei', 'Vôlei', FollowKind.esporte, ['volei']),
];

const customPrefix = 'custom:';

/// Rótulo do item seguido ("custom:Real Madrid" → "Real Madrid").
String followLabel(String id) {
  if (id.startsWith(customPrefix)) return id.substring(customPrefix.length);
  return sportsCatalog.where((t) => t.id == id).firstOrNull?.label ?? id;
}

String teamSourceId(String slug) => 'ge-time-$slug';

/// Feeds extras dos times seguidos.
List<NewsSource> teamSources(Iterable<String> followed) => [
  for (final t in sportsCatalog)
    if (t.geSlug != null && followed.contains(t.id))
      NewsSource(
        teamSourceId(t.geSlug!),
        'ge',
        'https://ge.globo.com/rss/ge/futebol/times/${t.geSlug}/',
        Topic.esportes,
      ),
];

bool _hasTerm(String text, String term) {
  final i = text.indexOf(term);
  if (i < 0) return false;
  return RegExp('(^|[^a-z0-9])${RegExp.escape(term)}(\$|[^a-z0-9])').hasMatch(text);
}

/// Sem nada seguido, tudo passa. Com seleção, notícias de esporte precisam citar um dos
/// times, ligas ou esportes escolhidos. Os outros temas não são afetados.
bool matchesFollow(NewsItem item, Set<String> followed) {
  if (followed.isEmpty || item.topic != Topic.esportes) return true;
  for (final t in sportsCatalog) {
    if (t.geSlug != null && followed.contains(t.id) && item.sourceId == teamSourceId(t.geSlug!)) return true;
  }
  final text = normalizeKeepLength('${item.title} ${item.summary}');
  for (final id in followed) {
    if (id.startsWith(customPrefix)) {
      if (_hasTerm(text, normalizeKeepLength(id.substring(customPrefix.length).trim()))) return true;
      continue;
    }
    final topic = sportsCatalog.where((t) => t.id == id).firstOrNull;
    if (topic != null && topic.aliases.any((a) => _hasTerm(text, a))) return true;
  }
  return false;
}
