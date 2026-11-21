import "package:flow/entity/transaction.dart";

/// Account name used by the converted Shark CSV files.
const legacySharkAccountName = "鲨鱼旧账";

/// Returns the name stored in the memo by the old Shark CSV converter.
String? legacySharkEntryName({
  required String? account,
  required String? category,
  required String? title,
  required String? note,
}) {
  if (account != legacySharkAccountName ||
      category == null ||
      title != category ||
      note == null ||
      note == category ||
      note.isEmpty ||
      note != note.trim() ||
      note.length > Transaction.maxTitleLength ||
      note.contains(RegExp(r"[\r\n]"))) {
    return null;
  }
  return note;
}
