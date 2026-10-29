import 'rss.dart';

const newsSources = <NewsSource>[
  NewsSource('g1-tec', 'g1 Tecnologia', 'https://g1.globo.com/rss/g1/tecnologia/', Topic.tecnologia),
  NewsSource('tecmundo', 'Tecmundo', 'https://rss.tecmundo.com.br/feed', Topic.tecnologia),
  NewsSource('canaltech', 'Canaltech', 'https://canaltech.com.br/rss/', Topic.tecnologia),
  NewsSource('olhar', 'Olhar Digital', 'https://olhardigital.com.br/feed/', Topic.tecnologia),
  NewsSource('ign', 'IGN Brasil', 'https://br.ign.com/feed.xml', Topic.games),
  NewsSource('g1-eco', 'g1 Economia', 'https://g1.globo.com/rss/g1/economia/', Topic.economia),
  NewsSource('infomoney', 'InfoMoney', 'https://www.infomoney.com.br/feed/', Topic.economia),
  NewsSource('moneytimes', 'Money Times', 'https://www.moneytimes.com.br/feed/', Topic.economia),
  NewsSource('g1-pol', 'g1 Política', 'https://g1.globo.com/rss/g1/politica/', Topic.brasil),
  NewsSource('agbrasil', 'Agência Brasil', 'https://agenciabrasil.ebc.com.br/rss/ultimasnoticias/feed.xml', Topic.brasil),
  NewsSource('folha', 'Folha', 'https://feeds.folha.uol.com.br/emcimadahora/rss091.xml', Topic.brasil),
  NewsSource('uol', 'UOL', 'https://rss.uol.com.br/feed/noticias.xml', Topic.brasil),
  NewsSource('ge', 'ge', 'https://ge.globo.com/rss/ge/', Topic.esportes),
  NewsSource('espn', 'ESPN', 'https://www.espn.com.br/rss', Topic.esportes),
];
