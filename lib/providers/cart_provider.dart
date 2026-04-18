import 'package:flutter/foundation.dart';

/// Grocery cart item from a recipe's ingredients.
class CartItem {
  final String name;
  final String amount;
  final String? unit;
  final String? recipeName;

  const CartItem({
    required this.name,
    required this.amount,
    this.unit,
    this.recipeName,
  });
}

/// Manages the grocery / shopping cart state.
class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  final Set<int> _checked = {};

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  int get checkedCount => _checked.length;

  bool isChecked(int index) => _checked.contains(index);

  void toggleCheck(int index) {
    if (_checked.contains(index)) {
      _checked.remove(index);
    } else {
      _checked.add(index);
    }
    notifyListeners();
  }

  void addItem(CartItem item) {
    // Avoid duplicates by name
    if (!_items.any((i) => i.name == item.name)) {
      _items.add(item);
      notifyListeners();
    }
  }

  void addItems(List<CartItem> newItems) {
    for (final item in newItems) {
      if (!_items.any((i) => i.name == item.name)) {
        _items.add(item);
      }
    }
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    // Rebuild checked set
    final newChecked = <int>{};
    for (final c in _checked) {
      if (c < index) {
        newChecked.add(c);
      } else if (c > index) {
        newChecked.add(c - 1);
      }
    }
    _checked
      ..clear()
      ..addAll(newChecked);
    notifyListeners();
  }

  void clearAll() {
    _items.clear();
    _checked.clear();
    notifyListeners();
  }

  void clearChecked() {
    final sorted = _checked.toList()..sort((a, b) => b.compareTo(a));
    for (final i in sorted) {
      _items.removeAt(i);
    }
    _checked.clear();
    notifyListeners();
  }
}
