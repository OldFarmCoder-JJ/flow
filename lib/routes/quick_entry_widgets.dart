part of "quick_entry_page.dart";

class _EntryMenu extends StatelessWidget {
  const _EntryMenu({required this.type, required this.enabled});

  final TransactionType type;
  final bool enabled;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    enabled: enabled,
    tooltip: "更多记账选项",
    icon: const Icon(Icons.more_horiz),
    onSelected: (path) => context.push(path),
    itemBuilder: (_) => [
      PopupMenuItem(
        value: "/transaction/new?type=${type.name}",
        child: const Text("完整记账"),
      ),
      const PopupMenuItem(
        value: "/transaction/new?type=transfer",
        child: Text("账户转账"),
      ),
      const PopupMenuItem(value: "/categories", child: Text("管理分类")),
    ],
  );
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.controller,
    required this.ready,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.enabled,
  });

  final ScrollController controller;
  final bool ready;
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<Category> onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Center(child: CircularProgressIndicator());
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    return LayoutBuilder(
      builder: (context, size) {
        final columns = size.maxWidth < 325 || scale > 1.4 ? 3 : 4;
        final firstCount = categories.length.clamp(0, 8);
        final grid = SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 56 + 19 * scale,
          mainAxisSpacing: 3,
          crossAxisSpacing: 4,
        );
        return CustomScrollView(
          controller: controller,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            if (categories.isEmpty)
              SliverToBoxAdapter(
                child: TextButton.icon(
                  onPressed: enabled ? () => context.push("/categories") : null,
                  icon: const Icon(Icons.add),
                  label: const Text("添加分类"),
                ),
              ),
            for (final (heading, start, end) in [
              if (firstCount > 0)
                (
                  firstCount == categories.length ? "选择分类" : "常用分类",
                  0,
                  firstCount,
                ),
              if (firstCount < categories.length)
                ("其他分类", firstCount, categories.length),
            ]) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Text(
                    heading,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid.builder(
                  gridDelegate: grid,
                  itemCount: end - start,
                  itemBuilder: (context, index) {
                    final category = categories[start + index];
                    return _CategoryTile(
                      category: category,
                      selected: category.uuid == selectedId,
                      onTap: enabled ? () => onSelect(category) : null,
                    );
                  },
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = category.name;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LedgerCategoryIcon(category: category, selected: selected),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.15,
                    color: colors.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryComposer extends StatelessWidget {
  const _EntryComposer({
    required this.category,
    required this.amount,
    required this.amountFocus,
    required this.name,
    required this.note,
    required this.noteFocus,
    required this.showNote,
    required this.onOpenNote,
    required this.photos,
    required this.dateLabel,
    required this.accountLabel,
    required this.busy,
    required this.pickingPhoto,
    required this.onDate,
    required this.onAccount,
    required this.onPhoto,
    required this.onRemove,
    required this.onSave,
  });

  final Category category;
  final TextEditingController amount;
  final FocusNode amountFocus;
  final TextEditingController name;
  final TextEditingController note;
  final FocusNode noteFocus;
  final bool showNote;
  final VoidCallback onOpenNote;
  final List<XFile> photos;
  final String dateLabel;
  final String accountLabel;
  final bool busy;
  final bool pickingPhoto;
  final VoidCallback onDate;
  final VoidCallback onAccount;
  final VoidCallback onPhoto;
  final ValueChanged<int> onRemove;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fieldDecoration = InputDecoration(
      counterText: "",
      isDense: true,
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.all(11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          children: [
            Row(
              children: [
                LedgerCategoryIcon(
                  category: category,
                  selected: true,
                  diameter: 28,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: amount,
                    focusNode: amountFocus,
                    enabled: !busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    textAlign: TextAlign.end,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) =>
                            _amountPattern.hasMatch(newValue.text)
                            ? newValue
                            : oldValue,
                      ),
                    ],
                    decoration: const InputDecoration(
                      hintText: "0.00",
                      labelText: "金额",
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: name,
                    enabled: !busy,
                    textInputAction: TextInputAction.done,
                    maxLength: Transaction.maxTitleLength,
                    style: const TextStyle(fontSize: 14),
                    decoration: fieldDecoration.copyWith(hintText: "名称（选填）"),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: busy ? null : onOpenNote,
                  tooltip: "添加备注",
                  icon: const Icon(Icons.note_add_outlined, size: 22),
                ),
                IconButton(
                  onPressed: busy || pickingPhoto ? null : onPhoto,
                  tooltip: "添加照片",
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 22,
                  ),
                ),
              ],
            ),
            if (showNote)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextField(
                  controller: note,
                  focusNode: noteFocus,
                  enabled: !busy,
                  textInputAction: TextInputAction.done,
                  maxLength: Transaction.maxDescriptionLength,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14),
                  decoration: fieldDecoration.copyWith(hintText: "备注（选填）"),
                ),
              ),
            if (photos.isNotEmpty)
              _EntryPhotos(photos: photos, onRemove: busy ? null : onRemove),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 2,
                    children: [
                      _EntryOption(
                        label: dateLabel,
                        icon: Icons.calendar_today_outlined,
                        onPressed: busy ? null : onDate,
                      ),
                      _EntryOption(
                        label: accountLabel,
                        icon: Icons.account_balance_wallet_outlined,
                        onPressed: busy ? null : onAccount,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: busy || pickingPhoto ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    minimumSize: const Size(76, 42),
                    textStyle: const TextStyle(fontSize: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: Text(busy ? "保存中" : "保存"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryOption extends StatelessWidget {
  const _EntryOption({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
  );
}

class _EntryPhotos extends StatelessWidget {
  const _EntryPhotos({required this.photos, required this.onRemove});

  final List<XFile> photos;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 66,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      scrollDirection: Axis.horizontal,
      itemCount: photos.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (context, index) => SizedBox(
        width: 64,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.file(
                File(photos[index].path),
                fit: BoxFit.cover,
                cacheWidth: 192,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
              ),
            ),
            if (onRemove case final remove?)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: "移除第 ${index + 1} 张照片",
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => remove(index),
                  icon: const Icon(Icons.close, size: 16),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _PhotoSources extends StatelessWidget {
  const _PhotoSources();

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (Platform.isAndroid || Platform.isIOS)
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text("拍照"),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text("从相册选择"),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}
