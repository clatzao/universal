import '../core/text_norm.dart';
import 'rss.dart';

const newsSources = <NewsSource>[
  NewsSource(
    'agbrasil',
    'Agência Brasil',
    'https://agenciabrasil.ebc.com.br/rss/ultimasnoticias/feed.xml',
    Topic.brasil,
  ),
  NewsSource(
    'agbrasil-geral',
    'Agência Brasil Geral',
    'https://agenciabrasil.ebc.com.br/rss/geral/feed.xml',
    Topic.brasil,
  ),
  NewsSource('folha', 'Folha', 'https://feeds.folha.uol.com.br/emcimadahora/rss091.xml', Topic.brasil),
  NewsSource('uol', 'UOL', 'https://rss.uol.com.br/feed/noticias.xml', Topic.brasil),
  NewsSource('g1-pol', 'g1 Política', 'https://g1.globo.com/rss/g1/politica/', Topic.politica),
  NewsSource(
    'agbrasil-pol',
    'Agência Brasil Política',
    'https://agenciabrasil.ebc.com.br/rss/politica/feed.xml',
    Topic.politica,
  ),
  NewsSource('poder360', 'Poder360', 'https://www.poder360.com.br/feed/', Topic.politica),
  NewsSource('g1-mundo', 'g1 Mundo', 'https://g1.globo.com/rss/g1/mundo/', Topic.mundo),
  NewsSource('bbc', 'BBC News Brasil', 'https://feeds.bbci.co.uk/portuguese/rss.xml', Topic.mundo),
  NewsSource(
    'agbrasil-int',
    'Agência Brasil Internacional',
    'https://agenciabrasil.ebc.com.br/rss/internacional/feed.xml',
    Topic.mundo,
  ),
  NewsSource('g1-eco', 'g1 Economia', 'https://g1.globo.com/rss/g1/economia/', Topic.economia),
  NewsSource('infomoney', 'InfoMoney', 'https://www.infomoney.com.br/feed/', Topic.economia),
  NewsSource('moneytimes', 'Money Times', 'https://www.moneytimes.com.br/feed/', Topic.economia),
  NewsSource('g1-tec', 'g1 Tecnologia', 'https://g1.globo.com/rss/g1/tecnologia/', Topic.tecnologia),
  NewsSource('tecmundo', 'Tecmundo', 'https://rss.tecmundo.com.br/feed', Topic.tecnologia),
  NewsSource('canaltech', 'Canaltech', 'https://canaltech.com.br/rss/', Topic.tecnologia),
  NewsSource('olhar', 'Olhar Digital', 'https://olhardigital.com.br/feed/', Topic.tecnologia),
  NewsSource(
    'agbrasil-saude',
    'Agência Brasil Saúde',
    'https://agenciabrasil.ebc.com.br/rss/saude/feed.xml',
    Topic.saude,
  ),
  NewsSource('fiocruz', 'Agência Fiocruz', 'https://agencia.fiocruz.br/rss.xml', Topic.saude),
  NewsSource('super', 'Superinteressante', 'https://super.abril.com.br/feed/', Topic.saude),
  NewsSource('canaltech-ciencia', 'Canaltech Ciência', 'https://canaltech.com.br/rss/ciencia/', Topic.saude),
  NewsSource('jornal-usp', 'Jornal da USP', 'https://jornal.usp.br/feed/', Topic.saude),
  NewsSource('g1-musica', 'g1 Música', 'https://g1.globo.com/rss/g1/pop-arte/musica/', Topic.entretenimento),
  NewsSource('cinepop', 'CinePOP', 'https://cinepop.com.br/feed/', Topic.entretenimento),
  NewsSource('rollingstone', 'Rolling Stone Brasil', 'https://rollingstone.com.br/feed/', Topic.entretenimento),
  NewsSource(
    'olhar-cinema',
    'Olhar Digital Cinema e Streaming',
    'https://olhardigital.com.br/cinema-e-streaming/feed/',
    Topic.entretenimento,
  ),
  NewsSource('ign', 'IGN Brasil', 'https://br.ign.com/feed.xml', Topic.games),
  NewsSource('ge', 'ge', 'https://ge.globo.com/rss/ge/', Topic.esportes),
  NewsSource('espn', 'ESPN', 'https://www.espn.com.br/rss', Topic.esportes),
];

const regionalSourceId = 'regiao';

/// Feed do g1 de cada estado (o caminho que estava com notícias recentes em nov/2026).
const _stateFeeds = {
  'acre': ('Acre', 'https://g1.globo.com/rss/g1/ac/'),
  'alagoas': ('Alagoas', 'https://g1.globo.com/rss/g1/al/alagoas/'),
  'amapa': ('Amapá', 'https://g1.globo.com/rss/g1/ap/amapa/'),
  'amazonas': ('Amazonas', 'https://g1.globo.com/rss/g1/am/amazonas/'),
  'bahia': ('Bahia', 'https://g1.globo.com/rss/g1/ba/bahia/'),
  'ceara': ('Ceará', 'https://g1.globo.com/rss/g1/ce/ceara/'),
  'distrito federal': ('Distrito Federal', 'https://g1.globo.com/rss/g1/df/distrito-federal/'),
  'espirito santo': ('Espírito Santo', 'https://g1.globo.com/rss/g1/es/espirito-santo/'),
  'goias': ('Goiás', 'https://g1.globo.com/rss/g1/go/goias/'),
  'maranhao': ('Maranhão', 'https://g1.globo.com/rss/g1/ma/maranhao/'),
  'mato grosso': ('Mato Grosso', 'https://g1.globo.com/rss/g1/mt/mato-grosso/'),
  'mato grosso do sul': ('Mato Grosso do Sul', 'https://g1.globo.com/rss/g1/ms/mato-grosso-do-sul/'),
  'minas gerais': ('Minas Gerais', 'https://g1.globo.com/rss/g1/mg/minas-gerais/'),
  'para': ('Pará', 'https://g1.globo.com/rss/g1/pa/para/'),
  'paraiba': ('Paraíba', 'https://g1.globo.com/rss/g1/pb/paraiba/'),
  'parana': ('Paraná', 'https://g1.globo.com/rss/g1/pr/parana/'),
  'pernambuco': ('Pernambuco', 'https://g1.globo.com/rss/g1/pe/'),
  'piaui': ('Piauí', 'https://g1.globo.com/rss/g1/pi/piaui/'),
  'rio de janeiro': ('Rio de Janeiro', 'https://g1.globo.com/rss/g1/rj/rio-de-janeiro/'),
  'rio grande do norte': ('Rio Grande do Norte', 'https://g1.globo.com/rss/g1/rn/rio-grande-do-norte/'),
  'rio grande do sul': ('Rio Grande do Sul', 'https://g1.globo.com/rss/g1/rs/rio-grande-do-sul/'),
  'rondonia': ('Rondônia', 'https://g1.globo.com/rss/g1/ro/'),
  'roraima': ('Roraima', 'https://g1.globo.com/rss/g1/rr/'),
  'santa catarina': ('Santa Catarina', 'https://ndmais.com.br/feed/'),
  'sao paulo': ('São Paulo', 'https://g1.globo.com/rss/g1/sp/sao-paulo/'),
  'sergipe': ('Sergipe', 'https://g1.globo.com/rss/g1/se/'),
  'tocantins': ('Tocantins', 'https://g1.globo.com/rss/g1/to/tocantins/'),
};

/// Fonte do estado da cidade escolhida ("Campinas, São Paulo, Brasil"), se for do Brasil.
NewsSource? regionalSource(String? cityName) {
  if (cityName == null) return null;
  final parts = cityName.split(',').map((p) => normalizeKeepLength(p.trim())).toList();
  // O estado vem depois da cidade; a cidade só vale quando é o único nome.
  for (final part in parts.length > 1 ? parts.skip(1) : parts) {
    final state = _stateFeeds[part];
    if (state == null) continue;
    final site = state.$2.contains('ndmais') ? 'ND+' : 'g1';
    return NewsSource(regionalSourceId, '$site ${state.$1}', state.$2, Topic.regiao);
  }
  return null;
}
