import "dart:io";

import "package:flow/data/ledger_stats.dart";
import "package:flow/entity/account.dart";
import "package:flow/entity/category.dart";
import "package:flow/entity/file_attachment.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/actions.dart";
import "package:flow/prefs/local_preferences.dart";
import "package:flow/providers/accounts_provider.dart";
import "package:flow/providers/categories_provider.dart";
import "package:flow/services/file_attachment.dart";
import "package:flow/services/user_preferences.dart";
import "package:flow/widgets/general/ledger_category_icon.dart";
import "package:flutter/cupertino.dart" show CupertinoSlidingSegmentedControl;
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:go_router/go_router.dart";
import "package:image_picker/image_picker.dart";
import "package:logging/logging.dart";
import "package:objectbox/objectbox.dart";

part "quick_entry_widgets.dart";

final _log = Logger("QuickEntryPage");
final _amountPattern = RegExp(r"^\d{0,10}([.,]\d{0,2})?$");
const _commonExpenses = [
  "餐饮",
  "购物",
  "日用",
  "交通",
  "零食",
  "娱乐",
  "通讯",
  "服饰",
  "住房",
  "医疗",
];
const _commonIncomes = ["工资", "奖金", "兼职", "红包", "退款", "理财", "收入"];

/// The single-screen entry flow for everyday income and expenses.
class QuickEntryPage extends StatefulWidget {
  const QuickEntryPage({super.key});

  @override
  State<QuickEntryPage> createState() => _QuickEntryPageState();
}

class _QuickEntryPageState extends State<QuickEntryPage> {
  final _amount = TextEditingController();
  final _name = TextEditingController();
  final _note = TextEditingController();
  final _amountFocus = FocusNode();
  final _noteFocus = FocusNode();
  final _photoPicker = ImagePicker();
  final List<XFile> _photos = [];
  final _gridScroll = ScrollController();
  final _lastAccountId = LocalPreferences().lastEntryAccountUuid.value;
  final _primaryAccountId = UserPreferencesService().value.primaryAccountUuid;
  TransactionType _type = TransactionType.expense;
  DateTime? _date;
  String? _categoryId;
  String? _accountId;
  bool _saving = false;
  bool _pickingPhoto = false;
  bool _showNote = false;

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    _note.dispose();
    _amountFocus.dispose();
    _noteFocus.dispose();
    _gridScroll.dispose();
    super.dispose();
  }

  List<Category> _categories(CategoriesProvider provider) {
    final priority = _type == TransactionType.expense
        ? _commonExpenses
        : _commonIncomes;
    return provider.categoriesFor(_type, defaults: priority);
  }

  Account? _account(List<Account> accounts) {
    if (accounts.isEmpty) return null;
    for (final id in [_accountId, _lastAccountId, _primaryAccountId]) {
      final match = accounts.where((account) => account.uuid == id).firstOrNull;
      if (match != null) return match;
    }
    return accounts.firstOrNull;
  }

  void _switchType(TransactionType type) {
    if (type == _type || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _type = type;
      _categoryId = null;
    });
    if (_gridScroll.hasClients) _gridScroll.jumpTo(0);
  }

  void _selectCategory(Category category) {
    if (_saving) return;
    setState(() => _categoryId = category.uuid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _amountFocus.requestFocus();
    });
  }

  void _openNote() {
    setState(() => _showNote = true);
    _noteFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final provider = CategoriesProvider.of(context);
    final accounts = AccountsProvider.of(context);
    final cnyAccounts = accounts.activeAccounts
        .where((account) => account.currency == ledgerCurrency)
        .toList();
    final pickedCategory = provider.get(_categoryId);
    final account = _account(cnyAccounts);
    final date = _date ?? DateTime.now();
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 48,
          leading: CloseButton(onPressed: _saving ? () {} : null),
          centerTitle: true,
          title: Semantics(
            label: "记账类型",
            child: CupertinoSlidingSegmentedControl<TransactionType>(
              groupValue: _type,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              thumbColor: Theme.of(context).colorScheme.surface,
              children: {
                for (final entry in const {
                  TransactionType.expense: "支出",
                  TransactionType.income: "收入",
                }.entries)
                  entry.key: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    child: Text(
                      entry.value,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _type == entry.key
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: _type == entry.key
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
              },
              onValueChanged: (value) {
                if (value != null) _switchType(value);
              },
            ),
          ),
          actions: [_EntryMenu(type: _type, enabled: !_saving)],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  children: [
                    Expanded(
                      child: _CategoryGrid(
                        controller: _gridScroll,
                        ready: provider.ready,
                        categories: _categories(provider),
                        selectedId: _categoryId,
                        onSelect: _selectCategory,
                        enabled: !_saving,
                      ),
                    ),
                    if (pickedCategory != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * .79,
                        ),
                        child: _EntryComposer(
                          category: pickedCategory,
                          amount: _amount,
                          amountFocus: _amountFocus,
                          name: _name,
                          note: _note,
                          noteFocus: _noteFocus,
                          showNote: _showNote,
                          onOpenNote: _openNote,
                          photos: _photos,
                          dateLabel: _date == null
                              ? "今天"
                              : "${date.month}月${date.day}日",
                          accountLabel:
                              account?.name ??
                              (accounts.ready ? "新建账户" : "读取账户"),
                          busy: _saving,
                          pickingPhoto: _pickingPhoto,
                          onDate: _pickDate,
                          onAccount: () => _pickAccount(cnyAccounts),
                          onPhoto: _pickPhotos,
                          onRemove: (index) =>
                              setState(() => _photos.removeAt(index)),
                          onSave: account == null
                              ? null
                              : () => _save(account, pickedCategory),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (date != null && mounted) {
      setState(() => _date = date == today ? null : date);
    }
  }

  Future<void> _pickAccount(List<Account> accounts) async {
    FocusScope.of(context).unfocus();
    if (accounts.isEmpty) {
      await context.push("/account/new");
      return;
    }
    final current = _account(accounts)?.uuid;
    final id = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final account in accounts)
            ListTile(
              title: Text(account.name),
              trailing: account.uuid == current
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, account.uuid),
            ),
        ],
      ),
    );
    if (id != null && mounted) setState(() => _accountId = id);
  }

  Future<void> _pickPhotos() async {
    FocusScope.of(context).unfocus();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _PhotoSources(),
    );
    if (source == null || !mounted) return;
    setState(() => _pickingPhoto = true);
    try {
      if (source == ImageSource.camera) {
        final photo = await _photoPicker.pickImage(source: source);
        if (photo != null && mounted) setState(() => _photos.add(photo));
      } else {
        final photos = await _photoPicker.pickMultiImage();
        if (mounted) setState(() => _photos.addAll(photos));
      }
    } catch (error, stackTrace) {
      _log.warning("Photo picker failed", error, stackTrace);
      _showMessage("无法添加照片，请检查相机或相册权限后重试");
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _save(Account account, Category category) async {
    if (_saving || _pickingPhoto) return;
    final raw = _amount.text.replaceAll(",", ".");
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0 || !_amountPattern.hasMatch(raw)) {
      _showMessage("请输入大于 0 的金额，最多两位小数");
      _amountFocus.requestFocus();
      return;
    }
    final name = _name.text.trim();
    final note = _note.text.trim();
    final date = _date ?? DateTime.now();
    final signedAmount = _type == TransactionType.expense ? -amount : amount;
    final attachments = <FileAttachment>[];
    setState(() => _saving = true);
    try {
      for (final photo in _photos) {
        final attachment = await FileAttachmentService().createFromXFile(
          photo,
          checkForOrphan: false,
        );
        if (attachment == null) throw const FileSystemException();
        attachments.add(attachment);
      }
      ObjectBox().store.runInTransaction(TxMode.write, () {
        account.createAndSaveTransaction(
          amount: signedAmount,
          title: name.isEmpty ? null : name,
          description: note.isEmpty ? null : note,
          category: category,
          transactionDate: date,
          attachments: attachments,
        );
      });
    } catch (error, stackTrace) {
      _log.warning("Quick entry save failed", error, stackTrace);
      for (final attachment in attachments) {
        try {
          await attachment.file.delete();
        } on FileSystemException catch (cleanupError) {
          _log.warning("Couldn't remove unsaved photo", cleanupError);
        }
      }
      if (mounted) setState(() => _saving = false);
      _showMessage("保存失败，请重试。若照片已失效，可移除后重新添加");
      return;
    }
    try {
      await LocalPreferences().lastEntryAccountUuid.set(account.uuid);
    } catch (error, stackTrace) {
      _log.warning("Couldn't remember the last account", error, stackTrace);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
