import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AikatsuApp());

class AikatsuApp extends StatelessWidget {
  const AikatsuApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Aikatsu! Collection',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE95B8A)),
      scaffoldBackgroundColor: const Color(0xFFFFFBF8),
      useMaterial3: true,
    ),
    home: const CollectionHome(),
  );
}

enum CardStatus { owned, wanted, trade, unowned }

class AikatsuCard {
  AikatsuCard({
    required this.seriesName,
    required this.volume,
    required this.number,
    required this.name,
    required this.rarity,
    required this.brand,
    required this.character,
    this.category = '',
    this.constellationRomance = '',
    required this.color,
    required this.status,
    this.imageUrl,
    this.favorite = false,
    this.ownedCount = 0,
  });

  final String seriesName;
  final String volume;
  final String number;
  final String name;
  final String rarity;
  final String brand;
  final String character;
  final String category;
  final String constellationRomance;
  final Color color;
  final String? imageUrl;
  CardStatus status;
  bool favorite;
  int ownedCount;

  String get series => seriesName;

  String get imageAssetPath => 'assets/$number.png';

  AikatsuCard copyWithMetadata({
    String? seriesName,
    String? volume,
    String? number,
    String? name,
    String? rarity,
    String? brand,
    String? character,
    String? category,
    String? constellationRomance,
    Color? color,
    String? imageUrl,
  }) => AikatsuCard(
    seriesName: seriesName ?? this.seriesName,
    volume: volume ?? this.volume,
    number: number ?? this.number,
    name: name ?? this.name,
    rarity: rarity ?? this.rarity,
    brand: brand ?? this.brand,
    character: character ?? this.character,
    category: category ?? this.category,
    constellationRomance: constellationRomance ?? this.constellationRomance,
    color: color ?? this.color,
    imageUrl: imageUrl ?? this.imageUrl,
    status: status,
    favorite: favorite,
    ownedCount: ownedCount,
  );
}

class CardMasterCsvLoader {
  static const assetPath = 'assets/card_master.csv';

  static Future<List<AikatsuCard>> load() async {
    final csv = await rootBundle.loadString(assetPath);
    return parse(csv);
  }

  static List<AikatsuCard> parse(String csv) {
    final rows = _parseRows(csv);
    if (rows.isEmpty) return [];
    final headers = rows.first.map((value) => value.trim()).toList();
    final index = {for (var i = 0; i < headers.length; i++) headers[i]: i};
    String value(List<String> row, List<String> names) {
      for (final name in names) {
        final position = index[name];
        if (position != null && position < row.length)
          return row[position].trim();
      }
      return '';
    }

    return rows
        .skip(1)
        .where((row) => value(row, ['number', 'カード番号']).isNotEmpty)
        .map((row) {
          final imageUrl = value(row, ['imageUrl', '画像']);
          return AikatsuCard(
            seriesName: value(row, ['series', 'シリーズ']),
            volume: value(row, ['volume', '弾']).isEmpty
                ? value(row, ['series', 'シリーズ'])
                : value(row, ['volume', '弾']),
            number: value(row, ['number', 'カード番号']),
            name: value(row, ['name', 'カード名']),
            rarity: value(row, ['rarity', 'レアリティ']),
            category: value(row, ['category', 'カテゴリー']),
            brand: value(row, ['brand', 'ブランド']),
            constellationRomance: value(row, [
              'constellationRomance',
              '星座・ロマンス',
              '星座、ロマンス',
            ]),
            character: value(row, ['character', 'キャラ']),
            imageUrl: imageUrl.isEmpty ? null : imageUrl,
            color: _colorFor(value(row, ['series', 'シリーズ'])),
            status: CardStatus.unowned,
          );
        })
        .toList();
  }

  static List<List<String>> _parseRows(String csv) {
    final rows = <List<String>>[];
    final row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < csv.length; i++) {
      final character = csv[i];
      if (character == '"') {
        if (quoted && i + 1 < csv.length && csv[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (character == ',' && !quoted) {
        row.add(field.toString());
        field.clear();
      } else if ((character == '\n' || character == '\r') && !quoted) {
        if (character == '\r' && i + 1 < csv.length && csv[i + 1] == '\n') i++;
        row.add(field.toString());
        field.clear();
        if (row.any((value) => value.trim().isNotEmpty))
          rows.add(List<String>.from(row));
        row.clear();
      } else {
        field.write(character);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  static Color _colorFor(String series) => series.contains('スター')
      ? const Color(0xFFC9D6F7)
      : series.contains('第2')
      ? const Color(0xFFFFDEB9)
      : const Color(0xFFFFC7D9);
}

bool cardMatchesSearch(AikatsuCard card, String rawQuery) {
  final query = _normalizeSearchText(rawQuery);
  if (query.isEmpty) return true;
  final fields = [
    card.number,
    card.name,
    card.character,
    card.brand,
    card.constellationRomance,
  ].map(_normalizeSearchText);
  final matchesField = fields.any((field) => field.contains(query));
  final searchesConstellation =
      query == '星座' && card.constellationRomance.trim().isNotEmpty;
  return matchesField || searchesConstellation;
}

String _normalizeSearchText(String value) {
  final normalized = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    if (codeUnit == 0x3000) {
      continue;
    }
    if (codeUnit >= 0xFF01 && codeUnit <= 0xFF5E) {
      normalized.writeCharCode(codeUnit - 0xFEE0);
    } else if (codeUnit == 0x20 || codeUnit == 0x09) {
      continue;
    } else {
      normalized.writeCharCode(codeUnit);
    }
  }
  return normalized.toString().toLowerCase();
}

class CollectionHome extends StatefulWidget {
  const CollectionHome({super.key});
  @override
  State<CollectionHome> createState() => _CollectionHomeState();
}

class _CollectionHomeState extends State<CollectionHome> {
  int _tab = 0;
  String _series = 'すべて';
  String _rarity = 'すべて';
  String _filter = 'すべて';
  String _query = '';
  final _cards = <AikatsuCard>[
    AikatsuCard(
      seriesName: '第1弾',
      volume: '第1弾',
      number: '01-01',
      name: '星宮 いちご',
      rarity: 'SR',
      brand: 'Angely Sugar',
      character: '星宮 いちご',
      color: const Color(0xFFFFC7D9),
      status: CardStatus.owned,
      favorite: true,
      ownedCount: 1,
    ),
    AikatsuCard(
      seriesName: '第1弾',
      volume: '第1弾',
      number: '01-04',
      name: '霧矢 あおい',
      rarity: 'R',
      brand: 'Futuring Girl',
      character: '霧矢 あおい',
      color: const Color(0xFFBEE6F4),
      status: CardStatus.owned,
      ownedCount: 1,
    ),
    AikatsuCard(
      seriesName: '第1弾',
      volume: '第1弾',
      number: '01-08',
      name: '紫吹 蘭',
      rarity: 'PR',
      brand: 'Spicy Ageha',
      character: '紫吹 蘭',
      color: const Color(0xFFE6C8F0),
      status: CardStatus.trade,
      ownedCount: 1,
    ),
    AikatsuCard(
      seriesName: '第2弾',
      volume: '第2弾',
      number: '02-03',
      name: '有栖川 おとめ',
      rarity: 'R',
      brand: 'Happy Rainbow',
      character: '有栖川 おとめ',
      color: const Color(0xFFFFDEB9),
      status: CardStatus.owned,
      ownedCount: 1,
    ),
    AikatsuCard(
      seriesName: '第2弾',
      volume: '第2弾',
      number: '02-12',
      name: '神崎 美月',
      rarity: 'SR',
      brand: 'Lovery Moon',
      character: '神崎 美月',
      color: const Color(0xFFFFE29D),
      status: CardStatus.wanted,
      favorite: true,
    ),
    AikatsuCard(
      seriesName: '第2弾',
      volume: '第2弾',
      number: '02-16',
      name: '一ノ瀬 かえで',
      rarity: 'N',
      brand: 'Aurora Fantasy',
      character: '一ノ瀬 かえで',
      color: const Color(0xFFBFEAD7),
      status: CardStatus.unowned,
    ),
    AikatsuCard(
      seriesName: 'スターライト',
      volume: 'スターライト',
      number: 'ST-01',
      name: '大空 あかり',
      rarity: 'R',
      brand: 'Dreamy Crown',
      character: '大空 あかり',
      color: const Color(0xFFFFC6C2),
      status: CardStatus.owned,
      ownedCount: 1,
    ),
    AikatsuCard(
      seriesName: 'スターライト',
      volume: 'スターライト',
      number: 'ST-05',
      name: '氷上 スミレ',
      rarity: 'SR',
      brand: 'Luminous',
      character: '氷上 スミレ',
      color: const Color(0xFFC9D6F7),
      status: CardStatus.wanted,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCardMaster();
  }

  Future<void> _loadCardMaster() async {
    try {
      final importedCards = await CardMasterCsvLoader.load();
      if (!mounted || importedCards.isEmpty) return;
      final existingState = {
        for (final card in _cards)
          card.number: (
            status: card.status,
            favorite: card.favorite,
            ownedCount: card.ownedCount,
          ),
      };
      final mergedCards = importedCards.map((card) {
        final state = existingState[card.number];
        if (state == null) return card;
        return card.copyWithMetadata()
          ..status = state.status
          ..favorite = state.favorite
          ..ownedCount = state.ownedCount;
      }).toList();
      setState(() {
        _cards
          ..clear()
          ..addAll(mergedCards);
      });
    } on Exception {
      // Keep the bundled fallback sample cards when the CSV is unavailable.
    }
  }

  List<String> get _seriesOptions => [
    'すべて',
    ..._cards.map((card) => card.seriesName).toSet(),
  ];

  List<String> get _rarityOptions => [
    'すべて',
    ..._cards
        .map((card) => card.rarity.trim())
        .where((rarity) => rarity.isNotEmpty)
        .toSet(),
  ];

  List<AikatsuCard> get _visibleCards => _cards.where((card) {
    final series = _series == 'すべて' || card.seriesName == _series;
    final rarity = _rarity == 'すべて' || card.rarity == _rarity;
    final filter =
        _filter == 'すべて' ||
        (_filter == 'お気に入り' && card.favorite) ||
        (_filter == '持っている' && _isOwned(card)) ||
        (_filter == '未所持' && !_isOwned(card)) ||
        (_filter == '欲しい' && card.status == CardStatus.wanted) ||
        (_filter == '交換' && card.status == CardStatus.trade);
    final query = cardMatchesSearch(card, _query);
    return series && rarity && filter && query;
  }).toList();

  bool _isOwned(AikatsuCard card) => card.ownedCount > 0;

  @override
  Widget build(BuildContext context) {
    final pages = [_dashboard(), _cardList(), _favorites()];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        indicatorColor: const Color(0xFFFFD8E4),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'ホーム',
          ),
          NavigationDestination(icon: Icon(Icons.style_outlined), label: 'カード'),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            label: 'お気に入り',
          ),
        ],
      ),
    );
  }

  Widget _header(String eyebrow, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: Color(0xFFE95B8A),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF282538),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    ),
  );

  Widget _dashboard() {
    final owned = _cards.where(_isOwned).length;
    final completion = _cards.isEmpty ? 0.0 : owned / _cards.length;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header('MY COLLECTION', 'カードコレクション')),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 22),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD7E5), Color(0xFFDDF5FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 116,
                  height: 116,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: completion,
                          strokeWidth: 11,
                          backgroundColor: Colors.white70,
                          color: const Color(0xFFE95B8A),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(completion * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF282538),
                            ),
                          ),
                          const Text(
                            'COMPLETE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: Color(0xFF8C5570),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'MY COLLECTION',
                            style: TextStyle(
                              color: Color(0xFFE95B8A),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.white.withOpacity(.9),
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '芸能人はカードが命！',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF282538),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '$owned / ${_cards.length} 枚を所持中',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6F5962),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: completion,
                          minHeight: 7,
                          backgroundColor: Colors.white70,
                          color: const Color(0xFFE95B8A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _sectionTitle('シリーズ別の進捗', 'すべて見る')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 158,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              scrollDirection: Axis.horizontal,
              children: _seriesOptions
                  .skip(1)
                  .map(_seriesProgressCard)
                  .toList(),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _sectionTitle('最近追加したカード', '一覧を見る')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .74,
            children: _cards.take(4).map(_recentCardTile).toList(),
          ),
        ),
      ],
    );
  }

  Widget _seriesProgressCard(String series) {
    final owned = _cards
        .where((card) => card.series == series && _isOwned(card))
        .length;
    final total = _cards.where((card) => card.series == series).length;
    final remaining = total - owned;
    final progress = total == 0 ? 0.0 : owned / total;
    return Container(
      width: 166,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF4DCE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  series,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF282538),
                  ),
                ),
              ),
              Icon(
                Icons.star_rounded,
                size: 18,
                color: progress == 1
                    ? const Color(0xFFFFC857)
                    : const Color(0xFFFFDCE8),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '所持 $owned / $total 枚',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4D4650),
            ),
          ),
          Text(
            'あと $remaining 枚',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFE95B8A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            borderRadius: BorderRadius.circular(4),
            color: const Color(0xFFE95B8A),
            backgroundColor: const Color(0xFFF9E6ED),
          ),
        ],
      ),
    );
  }

  Widget _recentCardTile(AikatsuCard card) => GestureDetector(
    onTap: () => _showCardSheet(card),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E8E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [card.color, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 30,
                          color: Colors.white.withOpacity(.95),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'CARD IMAGE',
                          style: TextStyle(
                            fontSize: 8,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => setState(() => card.favorite = !card.favorite),
                    child: Icon(
                      card.favorite ? Icons.favorite : Icons.favorite_border,
                      color: card.favorite
                          ? const Color(0xFFE95B8A)
                          : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        card.series,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      card.number,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sectionTitle(String title, String action) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 26, 22, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          action,
          style: const TextStyle(
            color: Color(0xFFE95B8A),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _cardList() => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: _header('CARD LIBRARY', 'カード一覧')),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'カード名・番号で検索',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['すべて', '持っている', '未所持', '欲しい', '交換']
                      .map(
                        (value) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(value),
                            selected: _filter == value,
                            onSelected: (_) => setState(() => _filter = value),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _series,
                decoration: const InputDecoration(
                  labelText: 'シリーズ',
                  border: OutlineInputBorder(),
                ),
                items: _seriesOptions
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _series = value!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _rarity,
                decoration: const InputDecoration(
                  labelText: 'レアリティ',
                  border: OutlineInputBorder(),
                ),
                items: _rarityOptions
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _rarity = value!),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _cardTile(_visibleCards[index], compact: true),
            childCount: _visibleCards.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            childAspectRatio: .48,
          ),
        ),
      ),
    ],
  );

  Widget _favorites() => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: _header('FAVORITES', 'お気に入り')),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
        sliver: SliverGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: .78,
          children: _cards
              .where((card) => card.favorite)
              .map(_cardTile)
              .toList(),
        ),
      ),
    ],
  );

  Widget _cardTile(AikatsuCard card, {bool compact = false}) => GestureDetector(
    onTap: () => _openCardDetail(card),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isOwned(card)
              ? const Color(0xFFF0B6CA)
              : const Color(0xFFF0E8E7),
          width: _isOwned(card) ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [card.color, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: _cardImage(card, compact ? 14 : 34, compact ? 2 : 8),
                  ),
                ),
                Positioned(top: 8, left: 8, child: _rarityBadge(card)),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => setState(() => card.favorite = !card.favorite),
                    child: Icon(
                      card.favorite ? Icons.favorite : Icons.favorite_border,
                      color: card.favorite
                          ? const Color(0xFFE95B8A)
                          : Colors.white,
                      size: compact ? 12 : 20,
                    ),
                  ),
                ),
                if (_isOwned(card))
                  Positioned(bottom: 8, left: 8, child: _ownedBadge()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFE95B8A),
                    fontSize: compact ? 7 : 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: compact ? 1 : 2),
                Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 8 : 13,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 3),
                  Text(
                    card.series,
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                  if (card.category.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      card.category,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  _statusLabel(card),
                ] else ...[
                  const SizedBox(height: 1),
                  Text(
                    card.rarity,
                    style: const TextStyle(
                      color: Color(0xFFE95B8A),
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _rarityBadge(AikatsuCard card) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.9),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      card.rarity,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Color(0xFFE95B8A),
      ),
    ),
  );

  Widget _ownedBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF4A9B78),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      '所持',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );

  Widget _statusLabel(AikatsuCard card) {
    final labels = {
      CardStatus.owned: '持っている',
      CardStatus.wanted: '欲しい',
      CardStatus.trade: '交換に出せる',
      CardStatus.unowned: '未所持',
    };
    return Text(
      labels[card.status]!,
      style: TextStyle(
        fontSize: 10,
        color: _isOwned(card)
            ? const Color(0xFF4A9B78)
            : const Color(0xFFE95B8A),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _cardImage(AikatsuCard card, double iconSize, double gap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        card.imageAssetPath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _imagePlaceholder(card, iconSize, gap),
      ),
    );
  }

  Widget _imagePlaceholder(AikatsuCard card, double iconSize, double gap) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: iconSize,
            color: Colors.white.withOpacity(.95),
          ),
          SizedBox(height: gap),
          Text(
            'CARD IMAGE',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 1.1,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(.9),
            ),
          ),
        ],
      );

  void _openCardDetail(AikatsuCard card) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CardDetailPage(
        card: card,
        isOwned: _isOwned(card),
        onStatusChanged: (status) => setState(() {
          card.status = status;
          if (status == CardStatus.owned && card.ownedCount == 0)
            card.ownedCount = 1;
          if (status == CardStatus.unowned) card.ownedCount = 0;
        }),
        onQuantityChanged: (_) => setState(() {}),
      ),
    ),
  );

  void _showCardSheet(AikatsuCard card) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            '${card.series}  ${card.number}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          const Text('カードの状態', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: CardStatus.values.map((status) {
              final labels = {
                CardStatus.owned: '持っている',
                CardStatus.wanted: '欲しい',
                CardStatus.trade: '交換に出せる',
                CardStatus.unowned: '未所持',
              };
              return ChoiceChip(
                label: Text(labels[status]!),
                selected: card.status == status,
                onSelected: (_) {
                  setState(() => card.status = status);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ],
      ),
    ),
  );
}

class CardDetailPage extends StatefulWidget {
  const CardDetailPage({
    super.key,
    required this.card,
    required this.isOwned,
    required this.onStatusChanged,
    required this.onQuantityChanged,
  });
  final AikatsuCard card;
  final bool isOwned;
  final ValueChanged<CardStatus> onStatusChanged;
  final ValueChanged<int> onQuantityChanged;

  @override
  State<CardDetailPage> createState() => _CardDetailPageState();
}

class _CardDetailPageState extends State<CardDetailPage> {
  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final labels = {
      CardStatus.owned: '持っている',
      CardStatus.wanted: '欲しい',
      CardStatus.trade: '交換に出せる',
      CardStatus.unowned: '未所持',
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('カード詳細'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
        children: [
          AspectRatio(
            aspectRatio: .72,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [card.color, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF0B6CA), width: 2),
              ),
              child: Image.asset(
                card.imageAssetPath,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_outlined, size: 58, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'CARD IMAGE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  card.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF282538),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => card.favorite = !card.favorite);
                },
                icon: Icon(
                  card.favorite ? Icons.favorite : Icons.favorite_border,
                  color: const Color(0xFFE95B8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${card.series}  /  ${card.number}',
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _detailChip('レアリティ', card.rarity),
              _detailChip('状態', labels[card.status]!),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _detailChip(
                'カテゴリー',
                card.category.isEmpty ? '未設定' : card.category,
              ),
              _detailChip('ブランド', card.brand.isEmpty ? '未設定' : card.brand),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _detailChip(
                '星座・ロマンス',
                card.constellationRomance.isEmpty
                    ? '未設定'
                    : card.constellationRomance,
              ),
              _detailChip(
                'キャラ',
                card.character.isEmpty ? '未設定' : card.character,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '所持枚数',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              _quantityButton(
                Icons.remove,
                card.ownedCount == 0,
                () => _changeQuantity(-1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  '${card.ownedCount}枚',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF282538),
                  ),
                ),
              ),
              _quantityButton(Icons.add, false, () => _changeQuantity(1)),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'コレクション状態',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CardStatus.values
                .map(
                  (status) => ChoiceChip(
                    label: Text(labels[status]!),
                    selected: card.status == status,
                    onSelected: (_) {
                      widget.onStatusChanged(status);
                      setState(() {});
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void _changeQuantity(int delta) {
    final nextCount = (widget.card.ownedCount + delta).clamp(0, 999);
    setState(() {
      widget.card.ownedCount = nextCount;
      widget.card.status = nextCount > 0
          ? CardStatus.owned
          : CardStatus.unowned;
    });
    widget.onQuantityChanged(nextCount);
    widget.onStatusChanged(widget.card.status);
  }

  Widget _quantityButton(
    IconData icon,
    bool disabled,
    VoidCallback onPressed,
  ) => IconButton(
    onPressed: disabled ? null : onPressed,
    icon: Icon(icon),
    style: IconButton.styleFrom(
      foregroundColor: const Color(0xFFE95B8A),
      backgroundColor: const Color(0xFFFFE8F0),
      disabledForegroundColor: const Color(0xFFD9C9CE),
    ),
  );

  Widget _detailChip(String label, String value) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0E8E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}
