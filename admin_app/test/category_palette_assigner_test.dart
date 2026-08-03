import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:local_pos/src/core/theme/category_tints.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('assigner persists random name-agnostic assignments', () async {
    final assigner = CategoryPaletteAssigner.instance;
    await assigner.ensureLoaded();
    expect(assigner.isLoaded, isTrue);

    final burgers = assigner.paletteIndexFor('Burgers');
    final pizza = assigner.paletteIndexFor('Pizza');
    final kebab = assigner.paletteIndexFor('Kebab');

    expect(burgers, inInclusiveRange(0, kCategoryPalettes.length - 1));
    expect(assigner.paletteIndexFor('Burgers'), burgers, reason: 'stable');
    expect(pizza, isNot(burgers), reason: 'first ten are distinct');
    expect(kebab, isNot(burgers));
    expect(kebab, isNot(pizza));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('category_palette_assignments'), contains('Burgers'));
  });

  test('resolvers route through palettes once loaded', () async {
    await CategoryPaletteAssigner.instance.ensureLoaded();
    final bg = resolveCategoryBg('Burgers');
    expect(kCategoryPalettes.map((p) => p.background), contains(bg));

    final chip = resolveCategoryChip('Burgers');
    expect(chip.background, bg);

    final accent = resolveCategoryAccent('Burgers');
    expect(
      kCategoryPalettes.map((p) => p.accent),
      contains(accent),
    );

    expect(resolveCategoryBg(''), kCategoryBgDefault);
    expect(resolveCategoryBg('All'), kCategoryBgDefault);
    expect(resolveCategoryBg('General'), kCategoryBgDefault);
  });
}
