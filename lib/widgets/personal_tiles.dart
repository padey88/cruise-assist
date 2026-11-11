import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/data.dart';
import '../theme.dart';
import 'tile.dart';
import 'tile_contract.dart';

List<ChecklistItem> checklistOf(TileContext ctx) =>
    payloadModels<ChecklistItem>(ctx, 'checklist', ChecklistItem.fromJson);

List<ChecklistItem> updateChecklist(
  TileContext ctx,
  List<ChecklistItem> items,
) {
  ctx.onConfigChanged({
    ...ctx.config,
    'items': items.map((e) => e.toJson()).toList(),
  });
  return items;
}

class ChecklistTile extends SimpleTile {
  const ChecklistTile()
    : super(
        'checklist',
        'Checklist',
        Icons.checklist,
        initialSpan: const SizeSpan(4, 3),
      );

  @override
  Widget build(BuildContext context, TileContext ctx) {
    final fromPayload = payloadModels<ChecklistItem>(
      ctx,
      'checklist',
      ChecklistItem.fromJson,
    );
    final items = fromPayload.isNotEmpty
        ? fromPayload
        : (ctx.config['items'] is List
              ? (ctx.config['items'] as List)
                    .whereType<Map>()
                    .map(
                      (j) => ChecklistItem.fromJson(j.cast<String, dynamic>()),
                    )
                    .toList()
              : <ChecklistItem>[]);
    final done = items.where((e) => e.done).length;
    return TileCard(
      title: 'Checklist',
      icon: icon,
      trailing: Text(
        '${items.isEmpty ? 0 : done}/${items.length}',
        style: const TextStyle(fontSize: 12, color: CA.dim),
      ),
      child: Column(
        children: [
          Expanded(
            child: items.isEmpty
                ? const TileMessage(
                    'Nothing on the list',
                    icon: Icons.playlist_add,
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final item in items)
                        InkWell(
                          key: Key('checklist-${item.id}'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => updateChecklist(ctx, [
                            for (final e in items)
                              e.id == item.id ? e.copyWith(done: !e.done) : e,
                          ]),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Icon(
                                  item.done
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 22,
                                  color: item.done ? CA.accent : CA.dim,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      decoration: item.done
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: item.done ? CA.dim : CA.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 44),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => _add(context, ctx, items),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add item', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    TileContext ctx,
    List<ChecklistItem> items,
  ) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add checklist item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(hintText: 'What needs doing?'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty) return;
    updateChecklist(ctx, [
      ...items,
      ChecklistItem(id: ctx.now.microsecondsSinceEpoch.toString(), text: text),
    ]);
  }
}

class NotesTile extends SimpleTile {
  const NotesTile()
    : super(
        'notes',
        'Notes',
        Icons.edit_note,
        initialSpan: const SizeSpan(4, 3),
      );

  @override
  Widget build(BuildContext context, TileContext ctx) {
    final notes = payloadModels<Note>(ctx, 'notes', Note.fromJson);
    final configNotes = (ctx.config['notes'] is List)
        ? (ctx.config['notes'] as List)
              .whereType<Map>()
              .map((e) => Note.fromJson(e.cast<String, dynamic>()))
              .toList()
        : <Note>[];
    final all = notes.isNotEmpty ? notes : configNotes;
    return TileCard(
      title: 'Notes',
      icon: icon,
      child: Column(
        children: [
          Expanded(
            child: all.isEmpty
                ? const TileMessage(
                    'No notes yet',
                    icon: Icons.note_add_outlined,
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: all.length,
                    separatorBuilder: (_, _) => const Divider(height: 10),
                    itemBuilder: (_, i) => Text(
                      all[i].text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.3),
                    ),
                  ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
              onPressed: () => _edit(context, ctx, all),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New note', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    TileContext ctx,
    List<Note> notes,
  ) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Write a note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty) return;
    ctx.onConfigChanged({
      ...ctx.config,
      'notes': [
        ...notes.map((e) => e.toJson()),
        Note(
          id: ctx.now.microsecondsSinceEpoch.toString(),
          text: text,
          updatedAt: ctx.now,
        ).toJson(),
      ],
    });
  }
}

class ShortcutsTile extends SimpleTile {
  const ShortcutsTile()
    : super(
        'shortcuts',
        'Shortcuts',
        Icons.apps_outlined,
        initialSpan: const SizeSpan(4, 2),
      );
  @override
  Widget build(BuildContext context, TileContext ctx) {
    final shortcuts = payloadModels<Shortcut>(
      ctx,
      'shortcuts',
      Shortcut.fromJson,
    );
    final configured = (ctx.config['shortcuts'] is List)
        ? (ctx.config['shortcuts'] as List)
              .whereType<Map>()
              .map((e) => Shortcut.fromJson(e.cast<String, dynamic>()))
              .toList()
        : <Shortcut>[];
    final all = shortcuts.isNotEmpty ? shortcuts : configured;
    return TileCard(
      title: 'Shortcuts',
      icon: icon,
      child: all.isEmpty
          ? const TileMessage(
              'No shortcuts configured',
              icon: Icons.add_to_home_screen,
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: all.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final s = all[i];
                return Material(
                  color: CA.glass,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _launch(s),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              s.package != null ? Icons.android : Icons.link,
                              size: 21,
                              color: CA.accent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            const Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: CA.dim,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _launch(Shortcut s) async {
    final uri = Uri.tryParse(
      s.uri ?? (s.package == null ? '' : 'android-app://${s.package}'),
    );
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
