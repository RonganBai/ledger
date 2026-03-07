import '../../data/db/app_database.dart';

class TxViewRow {
  final Transaction tx;
  final Category? category;
  TxViewRow({required this.tx, required this.category});
}

sealed class LedgerListItem {}
class HeaderItem extends LedgerListItem {
  final String title;
  HeaderItem(this.title);
}
class TxItem extends LedgerListItem {
  final TxViewRow row;
  TxItem(this.row);
}
