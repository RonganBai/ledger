import 'models.dart';

abstract class LedgerListEntry {
  const LedgerListEntry();
}

class LedgerHeaderEntry extends LedgerListEntry {
  final String title;
  const LedgerHeaderEntry(this.title);
}

class LedgerTxEntry extends LedgerListEntry {
  final TxViewRow row;
  const LedgerTxEntry(this.row);
}
