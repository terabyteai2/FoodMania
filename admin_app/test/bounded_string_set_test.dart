import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/core/utils/bounded_string_set.dart';

void main() {
  group('BoundedStringSet', () {
    test('honours insertion order via iterator', () {
      final set = BoundedStringSet(cap: 5);
      set.addAll(['a', 'b', 'c']);
      expect(set.toList(), ['a', 'b', 'c']);
    });

    test('deduplicates without reordering existing entries', () {
      final set = BoundedStringSet(cap: 5);
      set
        ..add('a')
        ..add('b')
        ..add('a');
      expect(set.length, 2);
      expect(set.toList(), ['a', 'b']);
    });

    test('evicts the oldest entry once cap is exceeded', () {
      final set = BoundedStringSet(cap: 3);
      set.addAll(['a', 'b', 'c', 'd']);
      expect(set.length, 3);
      expect(set.contains('a'), isFalse);
      expect(set.toList(), ['b', 'c', 'd']);
    });

    test('stays at cap after many adds beyond capacity', () {
      final set = BoundedStringSet(cap: 2000);
      for (var i = 0; i < 2500; i++) {
        set.add('id-$i');
      }
      expect(set.length, 2000);
      // The oldest 500 should have been evicted; the newest 2000 retained.
      expect(set.contains('id-0'), isFalse);
      expect(set.contains('id-499'), isFalse);
      expect(set.contains('id-500'), isTrue);
      expect(set.contains('id-2499'), isTrue);
    });

    test('clear empties the set', () {
      final set = BoundedStringSet(cap: 5);
      set.addAll(['a', 'b', 'c']);
      set.clear();
      expect(set.isEmpty, isTrue);
      expect(set.length, 0);
    });

    test('remove deletes a specific entry', () {
      final set = BoundedStringSet(cap: 5);
      set.addAll(['a', 'b', 'c']);
      expect(set.remove('b'), isTrue);
      expect(set.contains('b'), isFalse);
      expect(set.toList(), ['a', 'c']);
    });
  });
}
