import "package:flutter/material.dart";
import "package:flow/data/merchant_mark.dart";

/// Search and maintain the device's merchant marks.
class MerchantMarksPage extends StatefulWidget {
  const MerchantMarksPage({super.key});
  @override
  State<MerchantMarksPage> createState() => _MarksState();
}

class _MarksState extends State<MerchantMarksPage> {
  String search = "";
  Future<void> edit([MerchantMark? old]) async {
    final result = await showDialog<MerchantMark>(
      context: context,
      builder: (_) => _Editor(old),
    );
    if (result == null || !mounted) return;
    final list = [...MerchantMark.all];
    if (old == null) {
      list.add(result);
    } else {
      list[list.indexOf(old)] = result;
    }
    await save(list);
  }

  Future<void> save(List<MerchantMark> list) async {
    try {
      await MerchantMark.save(list);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("保存失败，请重试")));
      }
    }
  }

  Future<void> remove(MerchantMark m) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("删除${m.name}图标？"),
        content: const Text("相关流水将使用分类图标。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("删除"),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await save([...MerchantMark.all]..remove(m));
  }

  @override
  Widget build(BuildContext context) {
    final rows = MerchantMark.all
        .where((m) => m.keys.any((k) => k.contains(search.toLowerCase())))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text("品牌图标"),
        actions: [
          IconButton(
            tooltip: "添加品牌",
            onPressed: () => edit(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: "搜索品牌或别名",
                ),
                onChanged: (v) => setState(() => search = v.trim()),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text("没有匹配的品牌"))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (c, i) {
                        final m = rows[i];
                        return ListTile(
                          leading: MerchantBadge(m),
                          title: Text(m.name),
                          subtitle: Text(m.aliases),
                          onTap: () => edit(m),
                          onLongPress: () => edit(m),
                          trailing: IconButton(
                            tooltip: "删除${m.name}",
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => remove(m),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor(this.old);
  final MerchantMark? old;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late String name = widget.old?.name ?? "",
      mark = widget.old?.mark ?? "",
      aliases = widget.old?.aliases ?? "";
  late int color = widget.old?.color ?? 0xff20568c;
  String? error;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.old == null ? "添加品牌" : "修改品牌"),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            initialValue: name,
            decoration: const InputDecoration(labelText: "品牌名称"),
            onChanged: (v) => name = v.trim(),
          ),
          TextFormField(
            initialValue: mark,
            maxLength: 8,
            decoration: const InputDecoration(labelText: "图标文字"),
            onChanged: (v) => mark = v.trim(),
          ),
          TextFormField(
            initialValue: aliases,
            decoration: const InputDecoration(labelText: "识别别名（空格分隔）"),
            onChanged: (v) => aliases = v.trim(),
          ),
          Wrap(
            children: [
              for (final n in {
                color,
                0xff20568c,
                0xffab3038,
                0xff217148,
                0xff795919,
                0xff754b89,
              })
                IconButton(
                  tooltip: "色值 ${n.toRadixString(16)}",
                  onPressed: () => setState(() => color = n),
                  icon: Icon(
                    n == color ? Icons.check_circle : Icons.circle,
                    color: Color(n),
                  ),
                ),
            ],
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text("取消"),
      ),
      FilledButton(
        onPressed: () {
          final result = MerchantMark(name, mark, color, aliases);
          if (name.isEmpty || mark.isEmpty) {
            setState(() => error = "请填写名称和图标文字");
            return;
          }
          if (MerchantMark.all
              .where((m) => m != widget.old)
              .any((m) => m.keys.intersection(result.keys).isNotEmpty)) {
            setState(() => error = "名称或别名与已有品牌重复");
            return;
          }
          Navigator.pop(context, result);
        },
        child: const Text("保存"),
      ),
    ],
  );
}
