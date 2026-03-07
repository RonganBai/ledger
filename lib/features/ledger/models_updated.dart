class MonthlyTx {
  final String id;
  final String direction; // income | expense
  final int amountCents;
  final DateTime occurredAt;
  final String categoryName; // resolved name at archive time
  final String? merchant;
  final String? memo;

  MonthlyTx({
    required this.id,
    required this.direction,
    required this.amountCents,
    required this.occurredAt,
    required this.categoryName,
    this.merchant,
    this.memo,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'direction': direction,
        'amountCents': amountCents,
        'occurredAtEpochMs': occurredAt.millisecondsSinceEpoch,
        'categoryName': categoryName,
        'merchant': merchant,
        'memo': memo,
      };

  static MonthlyTx fromJson(Map<String, dynamic> json) {
    return MonthlyTx(
      id: json['id'] as String,
      direction: (json['direction'] as String?) ?? 'expense',
      amountCents: (json['amountCents'] as num).toInt(),
      occurredAt: DateTime.fromMillisecondsSinceEpoch((json['occurredAtEpochMs'] as num).toInt()),
      categoryName: (json['categoryName'] as String?) ?? 'Uncategorized',
      merchant: json['merchant'] as String?,
      memo: json['memo'] as String?,
    );
  }
}

class MonthlyReport {
  final String monthKey; // yyyy-MM
  final int incomeCents;
  final int expenseCents;
  final Map<String, int> expenseByCategoryCents; // categoryName -> cents
  final List<MonthlyTx> transactions; // full month tx snapshot for history
  final int createdAtEpochMs;

  MonthlyReport({
    required this.monthKey,
    required this.incomeCents,
    required this.expenseCents,
    required this.expenseByCategoryCents,
    required this.transactions,
    required this.createdAtEpochMs,
  });

  int get netCents => incomeCents - expenseCents;

  Map<String, dynamic> toJson() => {
        'monthKey': monthKey,
        'incomeCents': incomeCents,
        'expenseCents': expenseCents,
        'expenseByCategoryCents': expenseByCategoryCents,
        'transactions': transactions.map((e) => e.toJson()).toList(),
        'createdAtEpochMs': createdAtEpochMs,
      };

  static MonthlyReport fromJson(Map<String, dynamic> json) {
    final mapRaw = (json['expenseByCategoryCents'] as Map?) ?? {};
    final map = (mapRaw as Map).map(
      (k, v) => MapEntry(k.toString(), (v as num).toInt()),
    );

    final txRaw = json['transactions'];
    final txs = (txRaw is List)
        ? txRaw
            .whereType<Map>()
            .map((e) => MonthlyTx.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <MonthlyTx>[];

    return MonthlyReport(
      monthKey: json['monthKey'] as String,
      incomeCents: (json['incomeCents'] as num).toInt(),
      expenseCents: (json['expenseCents'] as num).toInt(),
      expenseByCategoryCents: map,
      transactions: txs,
      createdAtEpochMs: (json['createdAtEpochMs'] as num).toInt(),
    );
  }
}
