import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class IngredientItem {
  final String id;
  final String name;
  final String category;
  final Color bgColor;
  final String imageEmoji;

  const IngredientItem({
    required this.id,
    required this.name,
    required this.category,
    required this.bgColor,
    required this.imageEmoji,
  });
}

// Data
const List<IngredientItem> kAllIngredients = [
  // Fruits
  IngredientItem(id: '1', name: 'Apple', category: 'Fruits', bgColor: Color(0xFFFF7A7A), imageEmoji: '🍎'),
  IngredientItem(id: '2', name: 'Avocado', category: 'Fruits', bgColor: Color(0xFFC4E8A5), imageEmoji: '🥑'),
  IngredientItem(id: '3', name: 'Banana', category: 'Fruits', bgColor: Color(0xFFFFF4B3), imageEmoji: '🍌'),
  IngredientItem(id: '4', name: 'Cherry', category: 'Fruits', bgColor: Color(0xFFFFB8C6), imageEmoji: '🍒'),
  IngredientItem(id: '5', name: 'Chestnut', category: 'Fruits', bgColor: Color(0xFFE8BD8C), imageEmoji: '🌰'),
  IngredientItem(id: '6', name: 'Blueberry', category: 'Fruits', bgColor: Color(0xFFD6EEF8), imageEmoji: '🫐'),
  IngredientItem(id: '7', name: 'Currant', category: 'Fruits', bgColor: Color(0xFFB5D4E6), imageEmoji: '🫐'),
  IngredientItem(id: '8', name: 'Strawberry', category: 'Fruits', bgColor: Color(0xFFFF6B6B), imageEmoji: '🍓'),
  IngredientItem(id: '9', name: 'Mixed Fruit', category: 'Fruits', bgColor: Color(0xFFFFC2D1), imageEmoji: '🍇'),
  
  // Vegetables
  IngredientItem(id: '10', name: 'Carrot', category: 'Vegetables', bgColor: Color(0xFFFFB347), imageEmoji: '🥕'),
  IngredientItem(id: '11', name: 'Broccoli', category: 'Vegetables', bgColor: Color(0xFFB8E994), imageEmoji: '🥦'),
  IngredientItem(id: '12', name: 'Tomato', category: 'Vegetables', bgColor: Color(0xFFFF8A8A), imageEmoji: '🍅'),
  IngredientItem(id: '13', name: 'Garlic', category: 'Vegetables', bgColor: Color(0xFFFFF2CC), imageEmoji: '🧄'),
  IngredientItem(id: '14', name: 'Onion', category: 'Vegetables', bgColor: Color(0xFFE6E6FA), imageEmoji: '🧅'),

  // Dairy & Eggs
  IngredientItem(id: '15', name: 'Milk', category: 'Dairy & Eggs', bgColor: Color(0xFFDFF9FB), imageEmoji: '🥛'),
  IngredientItem(id: '16', name: 'Egg', category: 'Dairy & Eggs', bgColor: Color(0xFFFEEAA0), imageEmoji: '🥚'),
  IngredientItem(id: '17', name: 'Cheese', category: 'Dairy & Eggs', bgColor: Color(0xFFF9CA24), imageEmoji: '🧀'),
  IngredientItem(id: '18', name: 'Butter', category: 'Dairy & Eggs', bgColor: Color(0xFFF6E58D), imageEmoji: '🧈'),

  // Meat
  IngredientItem(id: '19', name: 'Beef', category: 'Meat', bgColor: Color(0xFFFF7979), imageEmoji: '🥩'),
  IngredientItem(id: '20', name: 'Chicken', category: 'Meat', bgColor: Color(0xFFFFBE76), imageEmoji: '🍗'),
  IngredientItem(id: '21', name: 'Pork', category: 'Meat', bgColor: Color(0xFFFFA502), imageEmoji: '🍖'),
  
  // Pantry
  IngredientItem(id: '22', name: 'Flour', category: 'Pantry', bgColor: Color(0xFFF1F2F6), imageEmoji: '🌾'),
  IngredientItem(id: '23', name: 'Sugar', category: 'Pantry', bgColor: Color(0xFFDFE4EA), imageEmoji: '🧂'),
  IngredientItem(id: '24', name: 'Salt', category: 'Pantry', bgColor: Color(0xFFCED6E0), imageEmoji: '🧂'),
  IngredientItem(id: '25', name: 'Olive Oil', category: 'Pantry', bgColor: Color(0xFFECCC68), imageEmoji: '🫒'),
];

class AddIngredientScreen extends StatefulWidget {
  const AddIngredientScreen({super.key});

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {
  final List<String> _categories = ['Fruits', 'Vegetables', 'Dairy & Eggs', 'Meat', 'Pantry'];
  String _selectedCategory = 'Fruits';
  final Set<String> _selectedIds = {};

  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Theme aware App Colors instead of hardcoded
    final surfaceColor = AppColors.background(context);
    final cardColor = AppColors.surfaceVariant(context);
    final inputBgColor = AppColors.surfaceVariant(context);
    final textPColor = AppColors.textPrimary(context);

    final filteredIngredients = kAllIngredients.where((item) {
      final matchesCategory = item.category == _selectedCategory;
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      if (_searchQuery.isNotEmpty) return matchesSearch;
      return matchesCategory;
    }).toList();
    
    // Check if empty
    final isNoneSelected = _selectedIds.isEmpty;

    return Scaffold(
      backgroundColor: surfaceColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // Header / Close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Ingredient',
                    style: TextStyle(
                      color: textPColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: inputBgColor,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: TextFormField(
                  controller: _searchController,
                  style: TextStyle(color: textPColor),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search ingredients...',
                    hintStyle: TextStyle(color: textPColor.withValues(alpha: 0.4), fontSize: 16),
                    prefixIcon: Icon(Icons.search, color: textPColor.withValues(alpha: 0.4)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Categories
            SizedBox(
              height: 40,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category && _searchQuery.isEmpty;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedCategory = category;
                      _searchQuery = '';
                      _searchController.clear();
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : textPColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : textPColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                itemCount: filteredIngredients.length,
                itemBuilder: (context, index) {
                  final item = filteredIngredients[index];
                  final isSelected = _selectedIds.contains(item.id);
                  return GestureDetector(
                    onTap: () => _toggleSelection(item.id),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: cardColor,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top part with color and emoji
                          Expanded(
                            flex: 5,
                            child: Container(
                              decoration: BoxDecoration(
                                color: item.bgColor,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Text(
                                      item.imageEmoji,
                                      style: const TextStyle(fontSize: 48),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected 
                                            ? AppColors.primary
                                            : Colors.black.withValues(alpha: 0.3),
                                        border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                                      ),
                                      child: isSelected 
                                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                                        : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Bottom part with text
                          Expanded(
                            flex: 2,
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                item.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textPColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Selection Bar
            Container(
              padding: EdgeInsets.only(
                left: 20, 
                right: 20, 
                top: 16, 
                bottom: 20
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    surfaceColor,
                    surfaceColor.withValues(alpha: 0.9),
                    surfaceColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (isNoneSelected) {
                      Navigator.pop(context);
                    } else {
                      final results = kAllIngredients.where((e) => _selectedIds.contains(e.id)).toList();
                      Navigator.pop(context, results);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isNoneSelected ? inputBgColor : AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isNoneSelected ? 'CANCEL' : 'ADD (${_selectedIds.length})',
                    style: TextStyle(
                      color: isNoneSelected ? textPColor : Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}