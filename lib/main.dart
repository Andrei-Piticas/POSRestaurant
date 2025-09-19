import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:io' show Platform;
import 'dart:typed_data';

void main() => runApp(const AppStateWrapper());

/// ===== DOMAIN MODELS =====
enum Category { pizza, hamburgers, desserts, beverages, service }

extension CategoryX on Category {
  String get label {
    switch (this) {
      case Category.pizza:
        return 'Pizza';
      case Category.hamburgers:
        return 'Hamburger';
      case Category.desserts:
        return 'Dolci';
      case Category.beverages:
        return 'Bevande';
      case Category.service:
        return 'Servizio';
    }
  }

  IconData get icon {
    switch (this) {
      case Category.pizza:
        return Icons.local_pizza_outlined;
      case Category.hamburgers:
        return Icons.lunch_dining_outlined;
      case Category.desserts:
        return Icons.icecream_outlined;
      case Category.beverages:
        return Icons.local_bar_outlined;
      case Category.service:
        return Icons.room_service_outlined;
    }
  }
}

enum ItemStatus { pending, sent }

class Modifier {
  final String id;
  String name;
  double price;
  Modifier({
    required this.id,
    required this.name,
    this.price = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
  };

  factory Modifier.fromJson(Map<String, dynamic> json) => Modifier(
    id: json['id'],
    name: json['name'],
    price: json['price'],
  );
}

class Product {
  final String id;
  String name;
  double price;
  Category category;
  List<String> ingredients;
  List<String> modifierIds;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.ingredients = const [],
    this.modifierIds = const [],
  });

  factory Product.withGeneratedModifiers({
    required String id,
    required String name,
    required double price,
    required Category category,
    List<String> ingredients = const [],
    List<String> modifierIds = const [],
  }) {
    return Product(
      id: id,
      name: name,
      price: price,
      category: category,
      ingredients: ingredients,
      modifierIds: modifierIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'category': category.name,
    'ingredients': ingredients,
    'modifierIds': modifierIds,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'],
    name: json['name'],
    price: json['price'],
    category: Category.values.byName(json['category']),
    ingredients: List<String>.from(json['ingredients'] ?? []),
    modifierIds: List<String>.from(json['modifierIds'] ?? []),
  );
}

class OrderItem {
  final Product product;
  final List<String> selectedModifierIds;
  final String chefNote;
  final int qty;
  final ItemStatus status;
  final List<Modifier> allModifiers;

  OrderItem({
    required this.product,
    this.selectedModifierIds = const [],
    this.chefNote = '',
    this.qty = 1,
    this.status = ItemStatus.pending,
    required this.allModifiers,
  });

  OrderItem copyWith({
    Product? product,
    List<String>? selectedModifierIds,
    String? chefNote,
    int? qty,
    ItemStatus? status,
  }) {
    return OrderItem(
      product: product ?? this.product,
      selectedModifierIds: selectedModifierIds ?? this.selectedModifierIds,
      chefNote: chefNote ?? this.chefNote,
      qty: qty ?? this.qty,
      status: status ?? this.status,
      allModifiers: allModifiers,
    );
  }

  double get lineTotal {
    final extraPrice = selectedModifierIds.fold(0.0, (sum, id) {
      final mod = allModifiers.firstWhere((m) => m.id == id);
      return sum + mod.price;
    });
    return (product.price + extraPrice) * qty;
  }

  String toKitchenLine() {
    final selectedMods = allModifiers
        .where((m) => selectedModifierIds.contains(m.id))
        .map((m) => m.name)
        .join(', ');
    final mods = selectedMods.isEmpty ? '' : ' [$selectedMods]';
    final note = chefNote.trim().isEmpty ? '' : ' â€” NOTA: $chefNote';
    return '${qty}Ã— ${product.name}$mods$note';
  }

  String toKitchenLineWithoutPrice() {
    final selectedMods = allModifiers
        .where((m) => selectedModifierIds.contains(m.id))
        .map((m) => m.name)
        .join(', ');
    final mods = selectedMods.isEmpty ? '' : ' [$selectedMods]';
    final note = chefNote.trim().isEmpty ? '' : ' â€” NOTA: $chefNote';
    return '${qty}Ã— ${product.name}$mods$note';
  }

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'selectedModifierIds': selectedModifierIds,
    'chefNote': chefNote,
    'qty': qty,
    'status': status.name,
    'allModifiers': allModifiers.map((e) => e.toJson()).toList(), // Save modifiers for context
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    product: Product.fromJson(json['product']),
    selectedModifierIds: List<String>.from(json['selectedModifierIds'] ?? []),
    chefNote: json['chefNote'],
    qty: json['qty'],
    status: ItemStatus.values.byName(json['status'] ?? ItemStatus.pending.name),
    allModifiers: (json['allModifiers'] as List).map((e) => Modifier.fromJson(e)).toList(),
  );
}

class TableOrder {
  final String id;
  final bool isTakeaway;
  final int peopleCount;
  final TimeOfDay? pickupTime;
  List<OrderItem> items;
  bool isClosed;
  final DateTime createdAt;

  TableOrder({
    required this.id,
    required this.isTakeaway,
    required this.peopleCount,
    this.pickupTime,
    this.items = const [],
    this.isClosed = false,
    required this.createdAt,
  });

  List<OrderItem> get newItems => items.where((item) => item.status == ItemStatus.pending).toList();

  double get total => items.fold(0.0, (s, it) => s + it.lineTotal);

  Map<String, dynamic> toJson() => {
    'id': id,
    'isTakeaway': isTakeaway,
    'peopleCount': peopleCount,
    'pickupTime': pickupTime != null ? '${pickupTime!.hour}:${pickupTime!.minute}' : null,
    'items': items.map((e) => e.toJson()).toList(),
    'isClosed': isClosed,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TableOrder.fromJson(Map<String, dynamic> json) {
    TimeOfDay? time;
    if (json['pickupTime'] != null) {
      final parts = json['pickupTime'].split(':');
      time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    return TableOrder(
      id: json['id'],
      isTakeaway: json['isTakeaway'],
      peopleCount: json['peopleCount'],
      pickupTime: time,
      items: (json['items'] as List).map((e) => OrderItem.fromJson(e)).toList(),
      isClosed: json['isClosed'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

/// ===== APP ROOT (STATEFUL) =====
class AppStateWrapper extends StatefulWidget {
  const AppStateWrapper({super.key});
  @override
  State<AppStateWrapper> createState() => _AppStateWrapperState();
}

class _AppStateWrapperState extends State<AppStateWrapper> {
  int _tab = 0;
  ThemeMode _themeMode = ThemeMode.light;
  final uuid = const Uuid();

  List<Product> products = [];
  List<TableOrder> tables = [];
  List<Modifier> modifiers = [];

  final Product _copertoProduct = Product(
    id: 'coperto',
    name: 'Coperto',
    price: 1.50,
    category: Category.service,
    ingredients: [],
    modifierIds: [],
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final productsJson = prefs.getString('products_key');
    final tablesJson = prefs.getString('tables_key');
    final modifiersJson = prefs.getString('modifiers_key');

    if (productsJson != null) {
      final List<dynamic> decoded = jsonDecode(productsJson);
      products = decoded.map((e) => Product.fromJson(e)).toList();
    }
    if (tablesJson != null) {
      final List<dynamic> decoded = jsonDecode(tablesJson);
      tables = decoded.map((e) => TableOrder.fromJson(e)).toList();
    }
    if (modifiersJson != null) {
      final List<dynamic> decoded = jsonDecode(modifiersJson);
      modifiers = decoded.map((e) => Modifier.fromJson(e)).toList();
    }
    setState(() {});
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('products_key', jsonEncode(products.map((e) => e.toJson()).toList()));
    await prefs.setString('tables_key', jsonEncode(tables.map((e) => e.toJson()).toList()));
    await prefs.setString('modifiers_key', jsonEncode(modifiers.map((e) => e.toJson()).toList()));
  }

  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      products = [];
      tables = [];
      modifiers = [];
    });
  }

  // ===== Mutations =====
  void setTab(int index) {
    setState(() => _tab = index);
  }

  void addTable({
    required bool takeaway,
    required int people,
    TimeOfDay? pickup,
  }) {
    final id = takeaway
        ? 'A-${tables.where((t) => t.isTakeaway).length + 1}'
        : 'T-${tables.where((t) => !t.isTakeaway).length + 1}';

    final List<OrderItem> initialItems = [];
    if (!takeaway) {
      initialItems.add(OrderItem(product: _copertoProduct, qty: people, allModifiers: modifiers));
    }

    setState(() {
      tables.add(TableOrder(
        id: id,
        isTakeaway: takeaway,
        peopleCount: takeaway ? 0 : people,
        pickupTime: takeaway ? pickup : null,
        items: initialItems,
        createdAt: DateTime.now(),
      ));
    });
    _saveData();
  }

  void addItemToTable(String tableId, OrderItem item) {
    final idx = tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    setState(() {
      tables[idx].items.add(item);
    });
    _saveData();
  }

  void updateItemInTable(String tableId, int itemIndex, OrderItem newItem) {
    final tableIdx = tables.indexWhere((t) => t.id == tableId);
    if (tableIdx == -1 || itemIndex >= tables[tableIdx].items.length) return;
    setState(() {
      tables[tableIdx].items[itemIndex] = newItem;
    });
    _saveData();
  }

  void removeItemFromTable(String tableId, int itemIndex) {
    final tableIdx = tables.indexWhere((t) => t.id == tableId);
    if (tableIdx == -1 || itemIndex >= tables[tableIdx].items.length) return;
    setState(() {
      tables[tableIdx].items.removeAt(itemIndex);
    });
    _saveData();
  }

  void markItemsAsSent(String tableId) {
    final tableIdx = tables.indexWhere((t) => t.id == tableId);
    if (tableIdx == -1) return;
    setState(() {
      final table = tables[tableIdx];
      final updatedItems = table.items.map((item) {
        if (item.status == ItemStatus.pending) {
          return item.copyWith(status: ItemStatus.sent);
        }
        return item;
      }).toList();
      tables[tableIdx] = TableOrder(
        id: table.id,
        isTakeaway: table.isTakeaway,
        peopleCount: table.peopleCount,
        pickupTime: table.pickupTime,
        items: updatedItems,
        isClosed: table.isClosed,
        createdAt: table.createdAt,
      );
    });
    _saveData();
  }

  void closeTable(String tableId) {
    final idx = tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    setState(() {
      tables[idx].isClosed = true;
    });
    _saveData();
  }

  void removeTable(String tableId) {
    setState(() {
      tables.removeWhere((t) => t.id == tableId);
    });
    _saveData();
  }

  void addProduct(Product p) {
    setState(() => products.add(p));
    _saveData();
  }

  void updateProduct(Product updatedProduct) {
    final index = products.indexWhere((p) => p.id == updatedProduct.id);
    if (index != -1) {
      setState(() {
        products[index] = updatedProduct;
      });
    }
    _saveData();
  }

  void addModifier(Modifier m) {
    setState(() => modifiers.add(m));
    _saveData();
  }

  void updateModifier(Modifier updatedModifier) {
    final index = modifiers.indexWhere((m) => m.id == updatedModifier.id);
    if (index != -1) {
      setState(() {
        modifiers[index] = updatedModifier;
      });
    }
    _saveData();
  }

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.montserrat().fontFamily,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        onPrimary: Colors.white,
        secondary: Colors.black,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black,
        background: Colors.white,
        onBackground: Colors.black,
        outlineVariant: Color(0xFFE0E0E0),
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.montserrat().fontFamily,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: Colors.black,
        secondary: Colors.white,
        onSecondary: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
        background: Colors.black,
        onBackground: Colors.white,
        outlineVariant: Color(0xFF424242),
      ),
    );

    return AppState(
      data: this,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'POS Demo',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: _themeMode,
        home: const _Home(),
      ),
    );
  }
}

class AppState extends InheritedWidget {
  final _AppStateWrapperState data;
  const AppState({required this.data, required super.child, super.key});

  static _AppStateWrapperState of(BuildContext context) {
    final AppState? state = context.dependOnInheritedWidgetOfExactType<AppState>();
    assert(state != null, 'No AppState found in context');
    return state!.data;
  }

  @override
  bool updateShouldNotify(covariant AppState oldWidget) => true;
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final pages = [
      const VendingPage(),
      const ReceiptsPage(),
      ArticlesPage(products: state.products, modifiers: state.modifiers),
      const ReportsPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[state._tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: state._tab,
        onDestinationSelected: (i) => state.setTab(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Vendita'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Scontrini'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Articoli'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'Report'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Impostazioni'),
        ],
      ),
    );
  }
}

/// ===== VENDING PAGE =====
class VendingPage extends StatefulWidget {
  const VendingPage({super.key});

  @override
  State<VendingPage> createState() => _VendingPageState();
}

class _VendingPageState extends State<VendingPage> {
  Category _filter = Category.pizza;
  String _searchQuery = '';
  final searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    searchCtrl.addListener(() {
      setState(() {
        _searchQuery = searchCtrl.text;
      });
    });
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final active = state.tables.where((t) => !t.isClosed).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Vendita')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Tavoli / Asporti Attivi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
          Expanded(
            child: active.isEmpty
                ? const Center(child: Text('Nessun tavolo attivo'))
                : ListView.separated(
              itemCount: active.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = active[i];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(t.isTakeaway ? 'A' : 'T'),
                  ),
                  title: Text('${t.id} â€¢ ${t.isTakeaway ? 'Asporto' : 'Tavolo'}'),
                  subtitle: Text(t.isTakeaway
                      ? (t.pickupTime != null ? 'Ritiro: ${t.pickupTime!.format(context)}' : 'Ritiro: â€”')
                      : 'Persone: ${t.peopleCount}'),
                  trailing: Text('â‚¬ ${t.total.toStringAsFixed(2)}'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TableDetailPage(tableId: t.id),
                  )),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewTableSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo Tavolo / Asporto'),
      ),
    );
  }

  void _showNewTableSheet(BuildContext context) {
    final state = AppState.of(context);
    bool takeaway = false;
    int people = 2;
    TimeOfDay? pickup;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Crea Nuovo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Asporto'),
                    value: takeaway,
                    onChanged: (v) => setSheet(() => takeaway = v),
                  ),
                  if (!takeaway)
                    Row(
                      children: [
                        const Text('Persone:'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Slider(
                            value: people.toDouble(),
                            min: 1,
                            max: 12,
                            divisions: 11,
                            label: '$people',
                            onChanged: (v) => setSheet(() => people = v.round()),
                          ),
                        ),
                        Text('$people'),
                      ],
                    ),
                  if (takeaway)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Ora ritiro: ${pickup == null ? 'â€”' : pickup!.format(ctx)}'),
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                          if (picked != null) setSheet(() => pickup = picked);
                        },
                        child: const Text('Seleziona'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Annulla'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            state.addTable(takeaway: takeaway, people: people, pickup: pickup);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Crea'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class TableDetailPage extends StatefulWidget {
  final String tableId;
  const TableDetailPage({super.key, required this.tableId});

  @override
  State<TableDetailPage> createState() => _TableDetailPageState();
}

class _TableDetailPageState extends State<TableDetailPage> {
  Category _filter = Category.pizza;
  String _searchQuery = '';
  final searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    searchCtrl.addListener(() {
      setState(() {
        _searchQuery = searchCtrl.text;
      });
    });
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final table = state.tables.firstWhere((t) => t.id == widget.tableId);
    final filtered = state.products
        .where((p) => p.category == _filter)
        .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${table.id} â€¢ ${table.isTakeaway ? 'Asporto' : 'Tavolo'}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Center(child: Text('Totale: â‚¬ ${table.total.toStringAsFixed(2)}')),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cerca prodotto...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: Category.values.map((c) {
                final selected = c == _filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(c.label),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = c),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = filtered[i];
                return _ProductListTileVending(
                  product: p,
                  onTap: () => _openItemDialog(context, table.id, p),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Scontrino per la Cucina', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (table.items.isEmpty)
                  const Text('Nessun articolo aggiunto.')
                else
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      itemCount: table.items.length,
                      itemBuilder: (context, i) {
                        final item = table.items[i];
                        final isSent = item.status == ItemStatus.sent;

                        return Dismissible(
                          key: ValueKey('${item.product.id}_$i'),
                          direction: isSent ? DismissDirection.none : DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            color: Theme.of(context).colorScheme.error,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            state.removeItemFromTable(table.id, i);
                          },
                          child: ListTile(
                            dense: true,
                            title: Text(
                              item.toKitchenLine(),
                              style: TextStyle(
                                decoration: isSent ? TextDecoration.lineThrough : null,
                                color: isSent ? Colors.grey : null,
                              ),
                            ),
                            leading: isSent ? const Icon(Icons.check, color: Colors.green) : null,
                            onLongPress: isSent ? null : () => _openItemDialog(context, table.id, item.product, item),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.print_outlined),
                        onPressed: table.newItems.isEmpty ? null : () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => KitchenPreviewPage(order: table),
                          ));
                        },
                        label: const Text('Stampa per la Cucina'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.receipt_long_outlined),
                        onPressed: table.items.isEmpty ? null : () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ReceiptDetailPage(tableId: table.id),
                          ));
                        },
                        label: const Text('Vedi Scontrino'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openItemDialog(
      BuildContext context,
      String tableId,
      Product product, [
        OrderItem? itemToEdit,
      ]) {
    final state = AppState.of(context);
    final isEditing = itemToEdit != null;

    final allModifiers = state.modifiers;
    final availableModifiers = allModifiers.where((m) => product.modifierIds.contains(m.id)).toList();

    final selectedModifiersNotifier = ValueNotifier<Set<String>>(
        isEditing ? itemToEdit!.selectedModifierIds.toSet() : {});
    final noteCtrl = TextEditingController(text: isEditing ? itemToEdit!.chefNote : '');
    final qtyNotifier = ValueNotifier<int>(isEditing ? itemToEdit!.qty : 1);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Modifica ${product.name}' : 'Aggiungi ${product.name}'),
        content: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: Listenable.merge([selectedModifiersNotifier, qtyNotifier]),
            builder: (ctx, child) {
              double basePrice = product.price;
              double modifiersPrice = selectedModifiersNotifier.value.fold(
                  0.0,
                      (sum, id) => sum + (allModifiers.firstWhere((m) => m.id == id)).price);
              double total = (basePrice + modifiersPrice) * qtyNotifier.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (availableModifiers.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Modificatori', style: Theme.of(ctx).textTheme.titleSmall),
                    ),
                  ...availableModifiers.map((m) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('${m.name} (+â‚¬${m.price.toStringAsFixed(2)})'),
                    value: selectedModifiersNotifier.value.contains(m.id),
                    onChanged: (v) {
                      final newSet = selectedModifiersNotifier.value.toSet();
                      if (v == true) {
                        newSet.add(m.id);
                      } else {
                        newSet.remove(m.id);
                      }
                      selectedModifiersNotifier.value = newSet;
                    },
                  )),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Nota per lo chef', style: Theme.of(ctx).textTheme.titleSmall),
                  ),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(hintText: 'es. tagliare in 8 fette'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('QuantitÃ '),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {
                          if (qtyNotifier.value > 0) {
                            qtyNotifier.value--;
                          }
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('${qtyNotifier.value}'),
                      IconButton(
                        onPressed: () => qtyNotifier.value++,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      const Spacer(),
                      Text('â‚¬ ${total.toStringAsFixed(2)}'),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              final newItem = OrderItem(
                product: product,
                selectedModifierIds: selectedModifiersNotifier.value.toList(),
                chefNote: noteCtrl.text,
                qty: qtyNotifier.value,
                allModifiers: allModifiers,
              );
              if (isEditing) {
                final itemIndex = state.tables.firstWhere((t) => t.id == tableId).items.indexOf(itemToEdit!);
                state.updateItemInTable(tableId, itemIndex, newItem);
              } else {
                state.addItemToTable(tableId, newItem);
              }
              Navigator.pop(ctx);
            },
            child: Text(isEditing ? 'Aggiorna' : 'Aggiungi'),
          ),
        ],
      ),
    );
  }
}

class _ProductListTileVending extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _ProductListTileVending({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(product.category.icon, size: 40, color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('â‚¬ ${product.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    product.ingredients.join(', '),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline, size: 30),
          ],
        ),
      ),
    );
  }
}

/// ===== RECEIPTS =====
class ReceiptsPage extends StatelessWidget {
  const ReceiptsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final active = state.tables.where((t) => !t.isClosed).toList();
    final closed = state.tables.where((t) => t.isClosed).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Scontrini')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Attivi'),
          if (active.isEmpty)
            const ListTile(title: Text('Nessuno scontrino attivo'))
          else
            ...active.map((t) => ListTile(
              leading: Icon(t.isTakeaway ? Icons.fastfood_outlined : Icons.table_restaurant_outlined),
              title: Text('${t.id} â€¢ ${t.isTakeaway ? 'Asporto' : 'Tavolo'}'),
              subtitle: t.isTakeaway && t.pickupTime != null
                  ? Text('Ritiro: ${t.pickupTime!.format(context)}')
                  : null,
              trailing: Text('â‚¬ ${t.total.toStringAsFixed(2)}'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReceiptDetailPage(tableId: t.id),
              )),
            )),
          const _SectionHeader(title: 'Chiusi'),
          if (closed.isEmpty)
            const ListTile(title: Text('Nessuno scontrino chiuso'))
          else
            ...closed.map((t) => ListTile(
              leading: Icon(t.isTakeaway ? Icons.fastfood : Icons.table_restaurant),
              title: Text(t.id),
              trailing: Text('â‚¬ ${t.total.toStringAsFixed(2)}'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReceiptDetailPage(tableId: t.id),
              )),
              onLongPress: () => AppState.of(context).removeTable(t.id),
            )),
        ],
      ),
    );
  }
}

class ReceiptDetailPage extends StatelessWidget {
  final String tableId;
  const ReceiptDetailPage({super.key, required this.tableId});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final table = state.tables.firstWhere((t) => t.id == tableId);

    return Scaffold(
      appBar: AppBar(title: Text('Scontrino â€¢ ${table.id}')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: ReceiptContent(order: table),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    onPressed: table.isClosed
                        ? null
                        : () {
                      _showCloseBillDialog(context, tableId);
                    },
                    label: const Text('Chiudi Conto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.print_outlined),
                    onPressed: table.items.isEmpty ? null : () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => PrintingPage(order: table, type: PrintingType.receipt, newItems: []),
                      ));
                    },
                    label: const Text('Stampa Scontrino'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showCloseBillDialog(BuildContext context, String tableId) {
    final state = AppState.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Chiudi Conto'),
          content: const Text('Sei sicuro di voler chiudere il conto?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                state.closeTable(tableId);
                Navigator.of(dialogContext).pop();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conto chiuso con successo!')),
                );
              },
              child: const Text('Conferma'),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// ===== ARTICLES PAGE =====
class ArticlesPage extends StatefulWidget {
  final List<Product> products;
  final List<Modifier> modifiers;
  const ArticlesPage({super.key, required this.products, required this.modifiers});

  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<ArticlesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final groupedProducts = widget.products.fold<Map<Category, List<Product>>>({}, (map, p) {
      map.putIfAbsent(p.category, () => []).add(p);
      return map;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Articoli'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Prodotti'),
            Tab(text: 'Modificatori'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Products Tab
          ListView(
            children: groupedProducts.keys.expand((category) {
              final productsInCategory = groupedProducts[category]!;
              return [
                _SectionHeader(title: category.label),
                ...productsInCategory.map((p) => ListTile(
                  leading: Icon(p.category.icon),
                  title: Text(p.name),
                  trailing: Text('â‚¬ ${p.price.toStringAsFixed(2)}'),
                  onTap: () => _showEditProductDialog(context, p),
                )).toList(),
              ];
            }).toList(),
          ),
          // Modifiers Tab
          ListView(
            children: [
              _SectionHeader(title: 'Modificatori'),
              ...widget.modifiers.map((m) => ListTile(
                title: Text(m.name),
                trailing: Text('â‚¬ ${m.price.toStringAsFixed(2)}'),
                onTap: () => _showEditModifierDialog(context, m),
              )).toList(),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddProductDialog(context);
          } else {
            _showAddModifierDialog(context);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    final state = AppState.of(context);
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final ingredientsCtrl = TextEditingController();
    Category category = Category.pizza;
    List<String> selectedModifiers = [];
    bool generateNegativeModifiers = false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aggiungi Prodotto'),
        content: StatefulBuilder(
          builder: (ctx, setDialog) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(labelText: 'Prezzo'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  DropdownButtonFormField<Category>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: Category.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                    onChanged: (c) { if (c != null) setDialog(() => category = c); },
                  ),
                  TextField(
                    controller: ingredientsCtrl,
                    decoration: const InputDecoration(labelText: 'Ingredienti (separati da virgola)'),
                  ),
                  SwitchListTile(
                    title: const Text('Genera modificatori "Senza"'),
                    value: generateNegativeModifiers,
                    onChanged: (v) => setDialog(() => generateNegativeModifiers = v),
                  ),
                  if (state.modifiers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Modificatori Disponibili', style: Theme.of(ctx).textTheme.titleSmall),
                    ),
                    ...state.modifiers.map((mod) => CheckboxListTile(
                      title: Text('${mod.name} (+â‚¬${mod.price.toStringAsFixed(2)})'),
                      value: selectedModifiers.contains(mod.id),
                      onChanged: (bool? value) {
                        setDialog(() {
                          if (value == true) {
                            selectedModifiers.add(mod.id);
                          } else {
                            selectedModifiers.remove(mod.id);
                          }
                        });
                      },
                    )).toList(),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              final ingredients = ingredientsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

              if (generateNegativeModifiers) {
                final existingNegativeMods = state.modifiers.where((m) => m.name.startsWith('Senza ')).toList();
                for (var ingredient in ingredients) {
                  final newModName = 'Senza $ingredient';
                  if (!existingNegativeMods.any((m) => m.name.toLowerCase() == newModName.toLowerCase())) {
                    final newModifier = Modifier(
                      id: state.uuid.v4(),
                      name: newModName,
                      price: 0.0,
                    );
                    state.addModifier(newModifier);
                  }
                }
                final newModifiers = state.modifiers.where((m) => m.name.startsWith('Senza ')).toList();
                selectedModifiers.addAll(newModifiers.where((m) => ingredients.contains(m.name.substring(6).trim())).map((e) => e.id));
              }

              final newProduct = Product(
                id: state.uuid.v4(),
                name: nameCtrl.text,
                price: double.tryParse(priceCtrl.text) ?? 0.0,
                category: category,
                ingredients: ingredients,
                modifierIds: selectedModifiers,
              );
              state.addProduct(newProduct);
              Navigator.pop(ctx);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, Product product) {
    final state = AppState.of(context);
    final nameCtrl = TextEditingController(text: product.name);
    final priceCtrl = TextEditingController(text: product.price.toString());
    final ingredientsCtrl = TextEditingController(text: product.ingredients.join(', '));
    Category category = product.category;
    List<String> selectedModifiers = product.modifierIds;
    bool generateNegativeModifiers = false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifica ${product.name}'),
        content: StatefulBuilder(
          builder: (ctx, setDialog) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(labelText: 'Prezzo'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  DropdownButtonFormField<Category>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: Category.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                    onChanged: (c) { if (c != null) setDialog(() => category = c); },
                  ),
                  TextField(
                    controller: ingredientsCtrl,
                    decoration: const InputDecoration(labelText: 'Ingredienti (separati da virgola)'),
                  ),
                  SwitchListTile(
                    title: const Text('Genera modificatori "Senza"'),
                    value: generateNegativeModifiers,
                    onChanged: (v) => setDialog(() => generateNegativeModifiers = v),
                  ),
                  if (state.modifiers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Modificatori Disponibili', style: Theme.of(ctx).textTheme.titleSmall),
                    ),
                    ...state.modifiers.map((mod) => CheckboxListTile(
                      title: Text('${mod.name} (+â‚¬${mod.price.toStringAsFixed(2)})'),
                      value: selectedModifiers.contains(mod.id),
                      onChanged: (bool? value) {
                        setDialog(() {
                          if (value == true) {
                            selectedModifiers.add(mod.id);
                          } else {
                            selectedModifiers.remove(mod.id);
                          }
                        });
                      },
                    )).toList(),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              final ingredients = ingredientsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

              if (generateNegativeModifiers) {
                final existingNegativeMods = state.modifiers.where((m) => m.name.startsWith('Senza ')).toList();
                for (var ingredient in ingredients) {
                  final newModName = 'Senza $ingredient';
                  if (!existingNegativeMods.any((m) => m.name.toLowerCase() == newModName.toLowerCase())) {
                    final newModifier = Modifier(
                      id: state.uuid.v4(),
                      name: newModName,
                      price: 0.0,
                    );
                    state.addModifier(newModifier);
                  }
                }
                final newModifiers = state.modifiers.where((m) => m.name.startsWith('Senza ')).toList();
                selectedModifiers.addAll(newModifiers.where((m) => ingredients.contains(m.name.substring(6).trim())).map((e) => e.id));
              }

              final updatedProduct = Product(
                id: product.id,
                name: nameCtrl.text,
                price: double.tryParse(priceCtrl.text) ?? 0.0,
                category: category,
                ingredients: ingredients,
                modifierIds: selectedModifiers,
              );
              state.updateProduct(updatedProduct);
              Navigator.pop(ctx);
            },
            child: const Text('Aggiorna'),
          ),
        ],
      ),
    );
  }

  void _showAddModifierDialog(BuildContext context) {
    final state = AppState.of(context);
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aggiungi Modificatore'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome modificatore'),
            ),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: 'Prezzo aggiuntivo'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              final newModifier = Modifier(
                id: state.uuid.v4(),
                name: nameCtrl.text,
                price: double.tryParse(priceCtrl.text) ?? 0.0,
              );
              state.addModifier(newModifier);
              Navigator.pop(ctx);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _showEditModifierDialog(BuildContext context, Modifier modifier) {
    final state = AppState.of(context);
    final nameCtrl = TextEditingController(text: modifier.name);
    final priceCtrl = TextEditingController(text: modifier.price.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifica ${modifier.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome modificatore'),
            ),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: 'Prezzo aggiuntivo'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              final updatedModifier = Modifier(
                id: modifier.id,
                name: nameCtrl.text,
                price: double.tryParse(priceCtrl.text) ?? 0.0,
              );
              state.updateModifier(updatedModifier);
              Navigator.pop(ctx);
            },
            child: const Text('Aggiorna'),
          ),
        ],
      ),
    );
  }
}

/// ===== REPORTS PAGE =====
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

enum ReportFilter { today, week, month, year, custom }

class _ReportsPageState extends State<ReportsPage> {
  ReportFilter _filter = ReportFilter.today;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _setFilterDates();
  }

  void _setFilterDates() {
    final now = DateTime.now();
    setState(() {
      switch (_filter) {
        case ReportFilter.today:
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case ReportFilter.week:
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          _startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case ReportFilter.month:
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case ReportFilter.year:
          _startDate = DateTime(now.year, 1, 1);
          _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
          break;
        case ReportFilter.custom:
        // Dates are set by the date picker
          break;
      }
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _filter = ReportFilter.custom;
        _startDate = picked.start;
        _endDate = picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final closedTables = state.tables.where((t) => t.isClosed).toList();

    final filteredTables = closedTables.where((t) {
      if (_startDate == null || _endDate == null) return false;
      return t.createdAt.isAfter(_startDate!) && t.createdAt.isBefore(_endDate!);
    }).toList();

    final dineInTables = filteredTables.where((t) => !t.isTakeaway).toList();
    final takeawayTables = filteredTables.where((t) => t.isTakeaway).toList();

    final dineInRevenue = dineInTables.fold(0.0, (sum, t) => sum + t.total);
    final takeawayRevenue = takeawayTables.fold(0.0, (sum, t) => sum + t.total);
    final totalRevenue = dineInRevenue + takeawayRevenue;

    final dineInBills = dineInTables.length;
    final takeawayBills = takeawayTables.length;
    final totalBills = dineInBills + takeawayBills;

    final Map<String, int> totalProductSales = {};
    for (var table in filteredTables) {
      for (var item in table.items) {
        totalProductSales.update(item.product.name, (count) => count + item.qty, ifAbsent: () => item.qty);
      }
    }
    final sortedProducts = totalProductSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final String dateRangeText = _filter == ReportFilter.custom
        ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
        : _filter.name.toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...ReportFilter.values.where((f) => f != ReportFilter.custom).map((f) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(f.name.toUpperCase()),
                    selected: _filter == f,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _filter = f;
                          _setFilterDates();
                        });
                      }
                    },
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    avatar: const Icon(Icons.date_range),
                    label: const Text('Personalizzato'),
                    onPressed: () => _selectDateRange(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Dati per il periodo: $dateRangeText',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (filteredTables.isEmpty)
            const Center(child: Text('Nessun dato disponibile per questo periodo.'))
          else ...[
            const Text('Riepilogo delle Vendite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _ReportCard(
              title: 'Incasso Totale',
              value: 'â‚¬ ${totalRevenue.toStringAsFixed(2)}',
              icon: Icons.attach_money,
            ),
            const SizedBox(height: 8),
            _ReportCard(
              title: 'Incasso Tavoli',
              value: 'â‚¬ ${dineInRevenue.toStringAsFixed(2)}',
              icon: Icons.table_restaurant,
            ),
            const SizedBox(height: 8),
            _ReportCard(
              title: 'Incasso Asporto',
              value: 'â‚¬ ${takeawayRevenue.toStringAsFixed(2)}',
              icon: Icons.fastfood,
            ),
            const Divider(height: 32),
            const Text('Numero Scontrini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _ReportCard(
              title: 'Scontrini Totali',
              value: '$totalBills',
              icon: Icons.receipt_long,
            ),
            const SizedBox(height: 8),
            _ReportCard(
              title: 'Scontrini Tavoli',
              value: '$dineInBills',
              icon: Icons.receipt_long,
            ),
            const SizedBox(height: 8),
            _ReportCard(
              title: 'Scontrini Asporto',
              value: '$takeawayBills',
              icon: Icons.receipt_long,
            ),
            const Divider(height: 32),
            const Text('Prodotti piÃ¹ Venduti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedProducts.length > 5 ? 5 : sortedProducts.length,
              itemBuilder: (context, index) {
                final entry = sortedProducts[index];
                return ListTile(
                  title: Text(entry.key),
                  trailing: Text('${entry.value} vendite'),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 40),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== SETTINGS PAGE =====
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('ModalitÃ  Scura'),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (_) => state.toggleTheme(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Esporta Dati di Backup'),
            onTap: () => _exportData(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('Cancella tutti i dati'),
            onTap: () => _showDeleteConfirmationDialog(context),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    final state = AppState.of(context);
    final textController = TextEditingController();

    // First confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('ATTENZIONE'),
          content: const Text('Sei sicuro di voler eliminare tutti i dati? Questa azione Ã¨ irreversibile.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Second confirmation dialog
                _showFinalDeleteDialog(context, textController, state);
              },
              child: const Text('Continua'),
            ),
          ],
        );
      },
    );
  }

  void _showFinalDeleteDialog(BuildContext context, TextEditingController textController, _AppStateWrapperState state) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('CONFERMA CANCELLAZIONE'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: 'Digita "CONFERMA"',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: textController,
              builder: (ctx, value, child) {
                return FilledButton(
                  onPressed: value.text == 'CONFERMA'
                      ? () {
                    state._clearAllData();
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dati cancellati con successo.')),
                    );
                  }
                      : null,
                  child: const Text('Elimina'),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final state = AppState.of(context);
    final prefs = await SharedPreferences.getInstance();
    final allData = {
      'products': jsonDecode(prefs.getString('products_key') ?? '[]'),
      'modifiers': jsonDecode(prefs.getString('modifiers_key') ?? '[]'),
      'tables': jsonDecode(prefs.getString('tables_key') ?? '[]'),
    };
    final jsonString = jsonEncode(allData);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final fileName = 'pos_backup_$timestamp.json';

    try {
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'json',
        mimeType: MimeType.json,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dati salvati in $fileName')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il salvataggio: $e')),
        );
      }
    }
  }
}

/// ===== NEW PAGES FOR KITCHEN LOGIC =====
class KitchenPreviewPage extends StatelessWidget {
  final TableOrder order;

  const KitchenPreviewPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final newItems = order.newItems;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Anteprima Cucina'),
            Text(order.isTakeaway ? 'Asporto ${order.id.split('-').last}' : 'Tavolo ${order.id.split('-').last}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: newItems.isEmpty
                  ? const Center(child: Text('Nessun articolo da inviare'))
                  : ListView.separated(
                itemCount: newItems.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final it = newItems[i];
                  return ListTile(
                    title: Text(it.toKitchenLineWithoutPrice()),
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annulla'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.print_outlined),
                    onPressed: newItems.isEmpty ? null : () {
                      state.markItemsAsSent(order.id);
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (context) => PrintingPage(
                          order: order,
                          type: PrintingType.kitchen,
                          newItems: newItems,
                        ),
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ordine inviato alla cucina!')),
                      );
                    },
                    label: const Text('Conferma Invio'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

enum PrintingType { kitchen, receipt }

class PrintingPage extends StatelessWidget {
  final TableOrder order;
  final PrintingType type;
  final List<OrderItem> newItems;

  const PrintingPage({
    super.key,
    required this.order,
    required this.type,
    required this.newItems,
  });

  @override
  Widget build(BuildContext context) {
    final title = type == PrintingType.kitchen ? 'Stampa per Cucina' : 'Stampa Scontrino';
    final items = type == PrintingType.kitchen ? newItems : order.items;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Stampa in corso...'),
            const SizedBox(height: 24),
            Text('Tavolo ${order.id}'),
            ...items.map((it) => Text(it.toKitchenLineWithoutPrice())),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Fatto'),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceiptContent extends StatelessWidget {
  final TableOrder order;
  const ReceiptContent({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final allModifiers = state.modifiers;
    final divider = 'â€”' * 32;
    final total = order.total.toStringAsFixed(2);
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final header = order.isTakeaway
        ? 'Asporto ${order.id.split('-').last}'
        : 'Tavolo ${order.id.split('-').last} (${order.peopleCount} pers.)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RISTORANTE POS',
          style: TextStyle(fontFamily: 'Courier New', fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        Text(
          now.toString().split(' ')[0],
          style: const TextStyle(fontFamily: 'Courier New'),
          textAlign: TextAlign.center,
        ),
        Text(
          time,
          style: const TextStyle(fontFamily: 'Courier New'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          header,
          style: const TextStyle(fontFamily: 'Courier New', fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          divider,
          style: const TextStyle(fontFamily: 'Courier New'),
        ),
        for (final item in order.items)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.qty} x ${item.product.name}',
                      style: const TextStyle(fontFamily: 'Courier New'),
                    ),
                  ),
                  Text(
                    '${item.lineTotal.toStringAsFixed(2)} â‚¬',
                    style: const TextStyle(fontFamily: 'Courier New'),
                  ),
                ],
              ),
              if (item.selectedModifierIds.isNotEmpty)
                ...item.selectedModifierIds.map((modId) {
                  final mod = allModifiers.firstWhere((m) => m.id == modId);
                  return Text(
                    '  - ${mod.name} (+â‚¬${mod.price.toStringAsFixed(2)})',
                    style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
                  );
                }),
              if (item.chefNote.isNotEmpty)
                Text(
                  '  * ${item.chefNote}',
                  style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
                ),
            ],
          ),
        Text(
          divider,
          style: const TextStyle(fontFamily: 'Courier New'),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TOTALE:',
              style: TextStyle(fontFamily: 'Courier New', fontWeight: FontWeight.bold),
            ),
            Text(
              '$total â‚¬',
              style: const TextStyle(fontFamily: 'Courier New', fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}