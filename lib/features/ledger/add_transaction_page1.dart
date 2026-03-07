import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as d;
import '../../l10n/category_i18n.dart';
import '../../data/db/app_database.dart';
import '../../l10n/tr.dart';

class AddTransactionPage extends StatefulWidget {
  final AppDatabase db;
  const AddTransactionPage({super.key, required this.db});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _amountController = TextEditingController();
  final _contentController = TextEditingController();
  final _detailController = TextEditingController();

  bool _isIncome = false;
  int? _categoryId;

  AppDatabase get db => widget.db;

  Future<List<Category>> _loadCategories() {
    final q = db.select(db.categories)
      ..where((c) => c.direction.equals(_isIncome ? 'income' : 'expense'))
      ..where((c) => c.isActive.equals(true))
      ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]);
    return q.get();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final content = _contentController.text.trim();
    final detail = _detailController.text.trim();

    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: id,
            accountId: 1,
            direction: d.Value(_isIncome ? 'income' : 'expense'),
            amountCents: (amount * 100).round(),
            occurredAt: DateTime.now(),
            categoryId: d.Value(_categoryId),
            merchant: d.Value(content.isEmpty ? null : content),
            memo: d.Value(detail.isEmpty ? null : detail),
          ),
        );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _contentController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  // Category display name:
  // - Prefer translations from category_i18n.dart
  // - If missing (returns the same as raw), provide a built-in zh fallback for common categories
  String _categoryDisplayName(BuildContext context, String raw) {
    final translated = categoryLabel(context, raw);
    if (translated != raw) return translated;

    final lang = Localizations.localeOf(context).languageCode.toLowerCase();
    final isZh = lang.startsWith('zh');
    if (!isZh) return raw;

    const zhFallback = <String, String>{
      // Expense
      'Food': '餐饮',
      'Dining': '餐饮',
      'Groceries': '杂货',
      'Shopping': '购物',
      'Transport': '交通',
      'Transportation': '交通',
      'Gas': '加油',
      'Fuel': '加油',
      'Rent': '房租',
      'Utilities': '水电煤',
      'Electricity': '电费',
      'Water': '水费',
      'Internet': '网络',
      'Phone': '电话费',
      'Entertainment': '娱乐',
      'Healthcare': '医疗',
      'Medical': '医疗',
      'Pharmacy': '药品',
      'Insurance': '保险',
      'Travel': '旅行',
      'Education': '教育',
      'Pets': '宠物',
      'Gift': '礼物',
      'Gifts': '礼物',
      'Other': '其他',

      // Income
      'Salary': '工资',
      'Wages': '工资',
      'Bonus': '奖金',
      'Interest': '利息',
      'Investment': '投资',
      'Investments': '投资',
      'Refund': '退款',
      'Reimbursement': '报销',
      'Transfer': '转账',
    };

    // Trim / normalize common stored values like "Food & Drink"
    final key = raw.trim();
    return zhFallback[key] ?? raw;
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = _isIncome ? tr(context, en: 'Income', zh: '收入') : tr(context, en: 'Expense', zh: '支出');

    return Scaffold(
      appBar: AppBar(title: Text('${tr(context, en: 'Add', zh: '添加')} $typeLabel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                if (!states.contains(MaterialState.selected)) return null;

                return _isIncome
                    ? Colors.green.withValues(alpha: 0.18)
                    : Colors.red.withValues(alpha: 0.18);
              }),
              foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                if (!states.contains(MaterialState.selected)) return null;

                return _isIncome ? Colors.green : Colors.red;
              }),
              side: MaterialStateProperty.resolveWith<BorderSide?>((states) {
                if (!states.contains(MaterialState.selected)) {
                  return const BorderSide(color: Colors.grey);
                }
                return BorderSide(
                  color: _isIncome ? Colors.green : Colors.red,
                  width: 1.5,
                );
              }),
            ),
            segments: [
              ButtonSegment(
                value: false,
                label: Text(tr(context, en: 'Expense', zh: '支出')),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              ButtonSegment(
                value: true,
                label: Text(tr(context, en: 'Income', zh: '收入')),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
            selected: {_isIncome},
            onSelectionChanged: (s) => setState(() {
              _isIncome = s.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),

          FutureBuilder<List<Category>>(
            future: _loadCategories(),
            builder: (context, snapshot) {
              final cats = snapshot.data ?? const <Category>[];
              if (cats.isEmpty) return const SizedBox.shrink();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(context, en: 'Category', zh: '类型'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in cats)
                            ChoiceChip(
                              label: Text(
                                _categoryDisplayName(context, c.name),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _categoryId == c.id
                                      ? (_isIncome ? Colors.green : Colors.red)
                                      : Colors.black87,
                                ),
                              ),
                              selected: _categoryId == c.id,
                              selectedColor: (_isIncome ? Colors.green : Colors.red).withValues(alpha: 0.15),
                              backgroundColor: Colors.grey.shade200,
                              side: BorderSide(
                                color: _categoryId == c.id
                                    ? (_isIncome ? Colors.green : Colors.red)
                                    : Colors.grey.shade400,
                              ),
                              onSelected: (_) => setState(() => _categoryId = c.id),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: tr(context, en: 'Amount', zh: '金额'),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _isIncome ? Colors.green : Colors.red,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            decoration: InputDecoration(
              labelText: tr(context, en: 'Content', zh: '消费内容'),
              hintText: tr(context, en: 'e.g. Starbucks / Gas / Amazon', zh: '例如：星巴克 / 加油 / 亚马逊'),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _isIncome ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: _save,
            child: Text(tr(context, en: 'Save', zh: '保存')),
          ),
        ],
      ),
    );
  }
}