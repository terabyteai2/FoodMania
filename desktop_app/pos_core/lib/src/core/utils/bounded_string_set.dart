import 'dart:collection';

/// Insertion-ordered string set with a fixed capacity. Adds past [cap] evict
/// the oldest entry — keeps RAM bounded without losing recency.
///
/// Used by [PosAppController] for the per-order alert dedupe sets that were
/// previously plain `Set<String>` and grew without bound over long sessions.
class BoundedStringSet extends Iterable<String> {
  BoundedStringSet({this.cap = 2000});

  final int cap;
  final LinkedHashSet<String> _set = LinkedHashSet<String>();

  @override
  Iterator<String> get iterator => _set.iterator;

  @override
  bool contains(Object? element) => _set.contains(element);

  @override
  int get length => _set.length;

  @override
  bool get isEmpty => _set.isEmpty;

  @override
  bool get isNotEmpty => _set.isNotEmpty;

  void add(String id) {
    if (_set.contains(id)) return;
    if (_set.length >= cap) {
      _set.remove(_set.first);
    }
    _set.add(id);
  }

  void addAll(Iterable<String> ids) {
    for (final id in ids) {
      add(id);
    }
  }

  bool remove(Object? id) => _set.remove(id);

  void clear() => _set.clear();
}
