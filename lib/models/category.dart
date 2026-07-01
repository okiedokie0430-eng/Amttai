/// Recipe category with optional icon.
class Category {
  final String id;
  final String name;
  final String? iconUrl;

  const Category({
    required this.id,
    required this.name,
    this.iconUrl,
  });

  /// Hard-coded default categories for MVP.
  static const List<Category> defaults = [
    Category(id: 'soup', name: 'Soup'),
    Category(id: 'main', name: 'Main Course'),
    Category(id: 'salad', name: 'Salad'),
    Category(id: 'bakery', name: 'Bakery'),
    Category(id: 'dessert', name: 'Dessert'),
    Category(id: 'drink', name: 'Drinks'),
    Category(id: 'breakfast', name: 'Breakfast'),
    Category(id: 'snack', name: 'Snack'),
    Category(id: 'traditional', name: 'Traditional'),
  ];
}
