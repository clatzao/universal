import 'package:flutter/material.dart';

enum FactCategory {
  ciencia('Ciência', Icons.science),
  espaco('Espaço', Icons.rocket_launch),
  historia('História', Icons.history_edu),
  antigo('Mundo antigo', Icons.account_balance),
  religioes('Religiões', Icons.temple_buddhist),
  culturas('Culturas', Icons.theater_comedy),
  paises('Países', Icons.public),
  tecnologia('Tecnologia', Icons.memory),
  games('Games', Icons.sports_esports),
  aleatorio('Aleatório', Icons.shuffle);

  final String label;
  final IconData icon;

  const FactCategory(this.label, this.icon);
}

class Fact {
  final int id;
  final FactCategory category;
  final String text;

  const Fact(this.id, this.category, this.text);
}

const _c = FactCategory.ciencia;
const _e = FactCategory.espaco;
const _h = FactCategory.historia;
const _a = FactCategory.antigo;
const _r = FactCategory.religioes;
const _cu = FactCategory.culturas;
const _p = FactCategory.paises;
const _t = FactCategory.tecnologia;
const _g = FactCategory.games;
const _x = FactCategory.aleatorio;

const facts = <Fact>[
  // Ciência
  Fact(1, _c, 'Ao nível do mar a água pura ferve a 100 °C; em lugares altos ela ferve a uma temperatura menor, porque a pressão atmosférica é mais baixa.'),
  Fact(2, _c, 'O esqueleto de um ser humano adulto tem 206 ossos.'),
  Fact(3, _c, 'O diamante e o grafite do lápis são feitos do mesmo elemento: carbono. A diferença está na forma como os átomos se organizam.'),
  Fact(4, _c, 'A luz do Sol leva cerca de 8 minutos e 20 segundos para chegar à Terra.'),
  Fact(5, _c, 'O genoma humano tem cerca de 3 bilhões de pares de bases de DNA.'),
  Fact(6, _c, 'O polvo tem três corações e sangue azulado, por causa da hemocianina, uma proteína que transporta oxigênio usando cobre.'),
  Fact(7, _c, 'O ouro é tão maleável que 1 grama pode ser batido até virar uma folha de cerca de 1 metro quadrado.'),
  Fact(8, _c, 'O som viaja a cerca de 343 m/s no ar a 20 °C e mais de quatro vezes mais rápido na água.'),
  Fact(9, _c, 'O hidrogênio é o elemento químico mais abundante do universo.'),
  Fact(10, _c, 'A banana é levemente radioativa: ela contém potássio-40, um isótopo natural do potássio. A dose é insignificante para a saúde.'),
  Fact(11, _c, 'O tardígrado, ou urso-d\'água, sobrevive à desidratação extrema entrando num estado chamado criptobiose.'),
  Fact(12, _c, 'Um raio aquece o ar ao redor a cerca de 30.000 °C, várias vezes mais que a superfície do Sol, que fica perto de 5.500 °C.'),
  // Espaço
  Fact(13, _e, 'Vênus gira tão devagar que uma rotação completa (cerca de 243 dias terrestres) dura mais que o seu ano (cerca de 225 dias).'),
  Fact(14, _e, 'Júpiter é o maior planeta do Sistema Solar: caberiam mais de 1.300 Terras dentro dele.'),
  Fact(15, _e, 'A Lua se afasta da Terra cerca de 3,8 centímetros por ano.'),
  Fact(16, _e, 'Neil Armstrong e Buzz Aldrin pisaram na Lua em 20 de julho de 1969, na missão Apollo 11.'),
  Fact(17, _e, 'O Monte Olimpo, em Marte, é o maior vulcão conhecido do Sistema Solar, com mais de 20 km de altura.'),
  Fact(18, _e, 'A densidade média de Saturno é menor que a da água.'),
  Fact(19, _e, 'A Estação Espacial Internacional dá uma volta completa na Terra a cada cerca de 90 minutos.'),
  Fact(20, _e, 'A estrela mais próxima do Sol é Proxima Centauri, a cerca de 4,24 anos-luz de distância.'),
  Fact(21, _e, 'Plutão foi reclassificado como planeta-anão pela União Astronômica Internacional em 2006.'),
  Fact(22, _e, 'Em 12 de abril de 1961, o soviético Yuri Gagarin se tornou o primeiro ser humano a ir ao espaço, a bordo da Vostok 1.'),
  Fact(23, _e, 'No centro da Via Láctea há um buraco negro supermassivo, Sagittarius A*, com cerca de 4 milhões de vezes a massa do Sol.'),
  Fact(24, _e, 'Em 2006, Marcos Pontes se tornou o primeiro astronauta brasileiro a ir ao espaço, numa missão à Estação Espacial Internacional.'),
  // História
  Fact(25, _h, 'A Lei Áurea, que aboliu a escravidão no Brasil, foi assinada pela princesa Isabel em 13 de maio de 1888.'),
  Fact(26, _h, 'A independência do Brasil foi proclamada por D. Pedro em 7 de setembro de 1822, às margens do riacho Ipiranga, em São Paulo.'),
  Fact(27, _h, 'Brasília foi inaugurada em 21 de abril de 1960, no governo de Juscelino Kubitschek.'),
  Fact(28, _h, 'O Muro de Berlim caiu em 9 de novembro de 1989.'),
  Fact(29, _h, 'A Primeira Guerra Mundial começou em 1914 e terminou em 1918.'),
  Fact(30, _h, 'Na Segunda Guerra Mundial, o Brasil enviou a Força Expedicionária Brasileira (FEB) para lutar na Itália.'),
  Fact(31, _h, 'A prensa de tipos móveis de Johannes Gutenberg surgiu em meados do século XV e revolucionou a difusão de livros na Europa.'),
  Fact(32, _h, 'A frota de Pedro Álvares Cabral chegou ao litoral do atual Brasil em 22 de abril de 1500.'),
  Fact(33, _h, 'A República foi proclamada no Brasil em 15 de novembro de 1889, pelo marechal Deodoro da Fonseca.'),
  Fact(34, _h, 'A Queda da Bastilha, em 14 de julho de 1789, é o marco simbólico da Revolução Francesa.'),
  Fact(35, _h, 'Santos Dumont voou com o 14-Bis em Paris, em 23 de outubro de 1906, diante de testemunhas e da imprensa.'),
  Fact(36, _h, 'A Constituição brasileira em vigor foi promulgada em 5 de outubro de 1988.'),
  // Mundo antigo
  Fact(37, _a, 'A Grande Pirâmide de Gizé foi a construção mais alta feita pelo ser humano por cerca de 3.800 anos.'),
  Fact(38, _a, 'Das Sete Maravilhas do Mundo Antigo, só a Grande Pirâmide de Gizé ainda existe.'),
  Fact(39, _a, 'Os hieróglifos egípcios foram decifrados por Jean-François Champollion em 1822, com a ajuda da Pedra de Roseta.'),
  Fact(40, _a, 'Júlio César foi assassinado nos Idos de Março, em 15 de março de 44 a.C.'),
  Fact(41, _a, 'A cidade romana de Pompeia foi soterrada pela erupção do Vesúvio em 79 d.C.'),
  Fact(42, _a, 'Os primeiros Jogos Olímpicos da Antiguidade registrados aconteceram em Olímpia, na Grécia, em 776 a.C.'),
  Fact(43, _a, 'O Código de Hamurabi, da Babilônia, é de cerca de 1750 a.C. e é um dos mais antigos conjuntos de leis escritas conhecidos.'),
  Fact(44, _a, 'A escrita cuneiforme, criada na Mesopotâmia por volta de 3200 a.C., está entre os sistemas de escrita mais antigos.'),
  Fact(45, _a, 'O Coliseu de Roma foi inaugurado no ano 80 d.C., sob o imperador Tito.'),
  Fact(46, _a, 'Alexandre, o Grande, morreu na Babilônia em 323 a.C., aos 32 anos.'),
  Fact(47, _a, 'É mito que a Muralha da China possa ser vista a olho nu da Lua: ela é longa, mas estreita demais.'),
  Fact(48, _a, 'O Panteão de Roma, de quase 1.900 anos, ainda tem a maior cúpula de concreto não armado do mundo.'),
  // Religiões
  Fact(49, _r, 'O cristianismo é a religião com mais seguidores no mundo, seguido pelo islamismo.'),
  Fact(50, _r, 'O Brasil é o país com o maior número de católicos do mundo.'),
  Fact(51, _r, 'O Ramadã é o nono mês do calendário islâmico; nele, os muçulmanos jejuam do amanhecer ao pôr do sol.'),
  Fact(52, _r, 'O budismo surgiu na Índia a partir dos ensinamentos de Siddhartha Gautama, o Buda, entre os séculos VI e V a.C.'),
  Fact(53, _r, 'O Hanukkah, a festa judaica das luzes, dura oito dias, e a cada noite se acende mais uma vela da hanukiá.'),
  Fact(54, _r, 'O Diwali, o festival das luzes, é uma das festas mais importantes do hinduísmo.'),
  Fact(55, _r, 'O Vaticano, sede da Igreja Católica, é o menor país do mundo, com cerca de 0,44 km².'),
  Fact(56, _r, 'O Cristo Redentor, no Rio de Janeiro, foi inaugurado em 1931 e tem 30 metros de altura, sem contar o pedestal de 8 metros.'),
  Fact(57, _r, 'O Círio de Nazaré, em Belém (PA), acontece no segundo domingo de outubro e é uma das maiores procissões católicas do mundo.'),
  Fact(58, _r, 'O sikhismo foi fundado por Guru Nanak no século XV, na região do Punjab, no sul da Ásia.'),
  Fact(59, _r, 'O Santuário Nacional de Aparecida (SP) é considerado o maior santuário mariano do mundo.'),
  Fact(60, _r, 'O candomblé é uma religião afro-brasileira que cultua os orixás, com raízes em tradições iorubás, fons e bantas.'),
  // Culturas
  Fact(61, _cu, 'O samba de roda do Recôncavo Baiano foi proclamado patrimônio imaterial da humanidade pela UNESCO em 2005.'),
  Fact(62, _cu, 'O frevo, de Pernambuco, foi inscrito como patrimônio cultural imaterial da humanidade pela UNESCO em 2012.'),
  Fact(63, _cu, 'A roda de capoeira foi reconhecida pela UNESCO como patrimônio cultural imaterial da humanidade em 2014.'),
  Fact(64, _cu, 'No Japão, é costume tirar os sapatos antes de entrar em casa.'),
  Fact(65, _cu, 'As festas do Dia dos Mortos, no México, são patrimônio cultural imaterial da humanidade reconhecido pela UNESCO.'),
  Fact(66, _cu, 'O português é língua oficial em nove países, de quatro continentes.'),
  Fact(67, _cu, 'O mandarim é a língua com mais falantes nativos do mundo.'),
  Fact(68, _cu, 'O hábito do chimarrão vem dos povos guaranis, que já consumiam a erva-mate antes da chegada dos europeus.'),
  Fact(69, _cu, 'O haicai é uma forma de poesia japonesa com três versos, tradicionalmente de 5, 7 e 5 sílabas.'),
  Fact(70, _cu, 'O Complexo Cultural do Bumba Meu Boi do Maranhão foi reconhecido pela UNESCO como patrimônio imaterial da humanidade em 2019.'),
  Fact(71, _cu, 'O "obrigado" vem da ideia de ficar "obrigado", isto é, em dívida com quem fez um favor.'),
  Fact(72, _cu, 'O Festival de Parintins, no Amazonas, é a disputa entre os bois-bumbás Garantido (vermelho) e Caprichoso (azul).'),
  // Países
  Fact(73, _p, 'A Rússia é o maior país do mundo em área.'),
  Fact(74, _p, 'O Brasil é o quinto maior país do mundo em área, com cerca de 8,5 milhões de km².'),
  Fact(75, _p, 'O Brasil faz fronteira com todos os países da América do Sul, exceto Chile e Equador.'),
  Fact(76, _p, 'Segundo estimativas da ONU, a Índia passou a China em 2023 e se tornou o país mais populoso do mundo.'),
  Fact(77, _p, 'O Canadá tem o litoral mais extenso do mundo.'),
  Fact(78, _p, 'A Bolívia tem duas capitais: Sucre, a capital constitucional, e La Paz, sede do governo.'),
  Fact(79, _p, 'A Islândia não tem forças armadas permanentes.'),
  Fact(80, _p, 'O rio Amazonas é o maior rio do mundo em volume de água.'),
  Fact(81, _p, 'A Mongólia é o país independente com a menor densidade populacional do mundo.'),
  Fact(82, _p, 'O Nepal é o único país cuja bandeira nacional não é retangular.'),
  Fact(83, _p, 'A Indonésia é o maior país-arquipélago do mundo, com mais de 17 mil ilhas.'),
  Fact(84, _p, 'O Lago Baikal, na Rússia, é o lago mais profundo do mundo, com mais de 1.600 metros de profundidade.'),
  // Tecnologia
  Fact(85, _t, 'O primeiro iPhone foi apresentado por Steve Jobs em janeiro de 2007.'),
  Fact(86, _t, 'A World Wide Web foi proposta por Tim Berners-Lee em 1989, quando ele trabalhava no CERN.'),
  Fact(87, _t, 'O ENIAC, um dos primeiros computadores eletrônicos de uso geral, foi concluído em 1945 e pesava cerca de 27 toneladas.'),
  Fact(88, _t, 'Em 1947, uma mariposa foi encontrada presa num relé do computador Harvard Mark II e registrada como o primeiro "bug" real encontrado.'),
  Fact(89, _t, 'O sistema Android é baseado no kernel Linux.'),
  Fact(90, _t, 'Ray Tomlinson enviou o primeiro e-mail entre computadores em rede em 1971 e escolheu o símbolo @ para os endereços.'),
  Fact(91, _t, 'O Pix, sistema de pagamentos instantâneos do Banco Central, começou a funcionar em novembro de 2020.'),
  Fact(92, _t, 'Em 1965, Gordon Moore previu que o número de transistores num chip dobraria periodicamente; em 1975, ele ajustou a previsão para a cada dois anos.'),
  Fact(93, _t, 'O QR Code foi inventado em 1994 pela empresa japonesa Denso Wave.'),
  Fact(94, _t, 'O primeiro domínio .com registrado foi symbolics.com, em 15 de março de 1985.'),
  Fact(95, _t, 'A urna eletrônica brasileira foi usada pela primeira vez nas eleições municipais de 1996.'),
  Fact(96, _t, 'O Bitcoin foi criado sob o pseudônimo Satoshi Nakamoto, e seu primeiro bloco foi minerado em janeiro de 2009.'),
  // Games
  Fact(97, _g, 'Tetris foi criado em 1984 por Alexey Pajitnov, na União Soviética.'),
  Fact(98, _g, 'Mario apareceu pela primeira vez em Donkey Kong, de 1981, com o nome de Jumpman.'),
  Fact(99, _g, 'Minecraft é o videogame mais vendido da história, com mais de 300 milhões de cópias.'),
  Fact(100, _g, 'Pac-Man foi lançado em 1980 pela Namco.'),
  Fact(101, _g, 'Pong, lançado pela Atari em 1972, foi um dos primeiros videogames de sucesso comercial.'),
  Fact(102, _g, 'A Tectoy lançou o Master System no Brasil em 1989, e versões do console continuaram sendo vendidas por aqui durante décadas.'),
  Fact(103, _g, 'O Game Boy foi lançado pela Nintendo em 1989.'),
  Fact(104, _g, 'Sonic the Hedgehog foi lançado pela Sega em 1991, para o Mega Drive.'),
  Fact(105, _g, 'The Legend of Zelda foi lançado em 1986 e criado por Shigeru Miyamoto e Takashi Tezuka.'),
  Fact(106, _g, 'O PlayStation 2 é o console de videogame mais vendido da história, com mais de 155 milhões de unidades.'),
  Fact(107, _g, 'Pokémon Red e Green foram lançados no Japão em 1996, para o Game Boy.'),
  Fact(108, _g, 'O primeiro Campeonato Mundial de League of Legends foi disputado em 2011.'),
  // Aleatório
  Fact(109, _x, 'O mel tem pouca água e é ácido, o que dificulta a vida de microrganismos; bem fechado, ele dura anos.'),
  Fact(110, _x, 'Os flamingos são cor-de-rosa por causa dos pigmentos carotenoides presentes no que eles comem.'),
  Fact(111, _x, 'O estômago da vaca é dividido em quatro compartimentos: rúmen, retículo, omaso e abomaso.'),
  Fact(112, _x, 'A girafa tem o mesmo número de vértebras no pescoço que os humanos: sete.'),
  Fact(113, _x, 'Os coalas dormem cerca de 18 a 22 horas por dia.'),
  Fact(114, _x, 'Os beija-flores conseguem pairar no ar e voar para trás, batendo as asas dezenas de vezes por segundo.'),
  Fact(115, _x, 'As impressões digitais dos coalas são tão parecidas com as humanas que é difícil diferenciá-las ao microscópio.'),
  Fact(116, _x, 'Os golfinhos dormem com metade do cérebro de cada vez, o que lhes permite continuar nadando e subir para respirar.'),
  Fact(117, _x, 'O Brasil é considerado o país com a maior biodiversidade do planeta.'),
  Fact(118, _x, 'A Floresta Amazônica se estende por nove países e territórios da América do Sul.'),
  Fact(119, _x, 'As abelhas informam às companheiras onde estão as flores por meio de uma "dança" feita dentro da colmeia.'),
  Fact(120, _x, 'O ornitorrinco é um mamífero que bota ovos.'),
];

/// Curiosidade do dia, determinística pela data.
Fact factOfDay(DateTime d) {
  final n = facts.length;
  final days = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2024, 1, 1)).inDays;
  // 37 é primo e não divide 120: percorre todas as curiosidades antes de repetir.
  const step = 37;
  final idx = ((days * step) % n + n) % n;
  return facts[idx];
}
