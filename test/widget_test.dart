import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aikatsu_card_collection/main.dart';

void main() {
  testWidgets('shows collection dashboard and navigates to cards', (
    tester,
  ) async {
    await tester.pumpWidget(const AikatsuApp());
    expect(find.text('カードコレクション'), findsOneWidget);
    expect(find.text('シリーズ別の進捗'), findsOneWidget);
    await tester.tap(find.text('カード'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('カード一覧'), findsOneWidget);
    expect(find.text('カード名・番号で検索'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('オーロラキスキャミソール'));
    await tester.pumpAndSettle();
    expect(find.text('カード詳細'), findsOneWidget);
  });

  testWidgets('filters the card list to unowned cards', (tester) async {
    await tester.pumpWidget(const AikatsuApp());
    await tester.tap(find.text('カード'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('未所持'));
    await tester.pumpAndSettle();
    expect(find.text('未所持'), findsWidgets);
  });

  testWidgets('changes owned quantity and status in card detail', (
    tester,
  ) async {
    final card = AikatsuCard(
      seriesName: '第1弾',
      volume: '第1弾',
      number: 'T-01',
      name: 'テストカード',
      rarity: 'R',
      brand: 'Test Brand',
      character: 'テストキャラ',
      color: Colors.pink,
      status: CardStatus.owned,
      ownedCount: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CardDetailPage(
          card: card,
          isOwned: true,
          onStatusChanged: (status) {},
          onQuantityChanged: (count) {},
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('1枚'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(card.ownedCount, 2);
    expect(find.text('2枚'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(card.ownedCount, 0);
    expect(card.status, CardStatus.unowned);
    expect(find.text('0枚'), findsOneWidget);
  });

  test('preserves collection state when card metadata is edited', () {
    final card = AikatsuCard(
      seriesName: '第1弾',
      volume: '第1弾',
      number: '01-01',
      name: '旧カード名',
      rarity: 'R',
      brand: 'Brand',
      character: 'Character',
      color: Colors.pink,
      status: CardStatus.owned,
      favorite: true,
      ownedCount: 3,
    );
    final edited = card.copyWithMetadata(
      name: '新カード名',
      brand: 'New Brand',
      imageUrl: 'https://example.com/card.png',
    );

    expect(edited.name, '新カード名');
    expect(edited.brand, 'New Brand');
    expect(edited.imageUrl, 'https://example.com/card.png');
    expect(edited.ownedCount, 3);
    expect(edited.favorite, isTrue);
    expect(edited.status, CardStatus.owned);
  });

  test('parses the nine card master columns', () {
    final cards = CardMasterCsvLoader.parse('''series,number,name,rarity,category,brand,constellationRomance,character,imageUrl
初代 第1弾,01-01,テストカード,SR,トップス,Angely Sugar,おひつじ座,星宮 いちご,https://example.com/card.png
''');

    expect(cards, hasLength(1));
    expect(cards.single.seriesName, '初代 第1弾');
    expect(cards.single.number, '01-01');
    expect(cards.single.category, 'トップス');
    expect(cards.single.brand, 'Angely Sugar');
    expect(cards.single.constellationRomance, 'おひつじ座');
    expect(cards.single.character, '星宮 いちご');
    expect(cards.single.imageUrl, 'https://example.com/card.png');
    expect(cards.single.ownedCount, 0);
    expect(cards.single.favorite, isFalse);
  });

  test('searches all card metadata fields flexibly', () {
    final card = AikatsuCard(
      seriesName: '第1弾',
      volume: '第1弾',
      number: '01-01',
      name: 'テストカード',
      rarity: 'Premium Rare',
      category: 'トップス',
      brand: 'Angely Sugar',
      constellationRomance: 'おひつじ座',
      character: '星宮いちご',
      color: Colors.pink,
      status: CardStatus.unowned,
    );

    expect(cardMatchesSearch(card, '01-01'), isTrue);
    expect(cardMatchesSearch(card, 'テストカード'), isTrue);
    expect(cardMatchesSearch(card, '星宮いちご'), isTrue);
    expect(cardMatchesSearch(card, 'angely sugar'), isTrue);
    expect(cardMatchesSearch(card, 'ＰＲＥＭＩＵＭ　ＲＡＲＥ'), isFalse);
    expect(cardMatchesSearch(card, '星座'), isTrue);
    expect(cardMatchesSearch(card, '存在しないカード'), isFalse);
  });

  testWidgets('displays cards loaded from the CSV asset', (tester) async {
    await tester.pumpWidget(const AikatsuApp());
    await tester.tap(find.text('カード'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('カード一覧'), findsOneWidget);
  });

  testWidgets('shows both series from the CSV card master', (tester) async {
    await tester.pumpWidget(const AikatsuApp());
    await tester.tap(find.text('カード'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('第2弾').last);
    await tester.pumpAndSettle();

    expect(find.text('第2弾'), findsWidgets);
  });

  test('parses distinct rarities for the rarity filter', () {
    final cards = CardMasterCsvLoader.parse(
      '''シリーズ,カード番号,カード名,レアリティ,カテゴリー,ブランド,星座、ロマンス,キャラ,画像
第1弾,01-01,プレミアムカード,プレミアムレア,トップス,ブランドA,,キャラA,
第1弾,01-02,レアカード,レア,トップス,ブランドA,,キャラA,
第1弾,01-03,ノーマルカード,ノーマル,トップス,ブランドA,,キャラA,
''',
    );

    final rarities = {'すべて', ...cards.map((card) => card.rarity)};
    expect(rarities, containsAll(['すべて', 'プレミアムレア', 'レア', 'ノーマル']));
  });
}
