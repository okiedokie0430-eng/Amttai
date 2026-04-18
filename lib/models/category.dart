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
    Category(id: 'soup', name: 'Шөл'),
    Category(id: 'main', name: 'Үндсэн хоол'),
    Category(id: 'salad', name: 'Салат'),
    Category(id: 'bakery', name: 'Нарийн боов'),
    Category(id: 'dessert', name: 'Амттан'),
    Category(id: 'drink', name: 'Ундаа'),
    Category(id: 'breakfast', name: 'Өглөөний хоол'),
    Category(id: 'snack', name: 'Зууш'),
    Category(id: 'traditional', name: 'Уламжлалт'),
  ];
}
