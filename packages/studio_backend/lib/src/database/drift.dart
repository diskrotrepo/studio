import 'package:drift/drift.dart';
import 'package:studio_backend/src/logger/logger.dart';

extension GeneratedDatabaseExt on GeneratedDatabase {
  OnUpgrade wrappedUpgrade(OnUpgrade onUpgrade) {
    return (m, from, to) async {
      if (from > to) {
        logger.e(message: 'Unexpected downgrade from $from to $to, halting.');
        return;
      }

      // Run the upgrade in a transaction.
      await transaction(() async {
        logger.i(message: 'Upgrading from $from to $to');
        await onUpgrade(m, from, to);
      });
    };
  }
}
