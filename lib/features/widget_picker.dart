import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/tile_contract.dart';

/// Bottom sheet listing every widget that can be added to the dashboard.
class WidgetPickerSheet extends StatelessWidget {
  const WidgetPickerSheet({
    super.key,
    required this.available,
    required this.onPick,
  });

  final List<TileRenderer> available;
  final void Function(TileRenderer) onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        maxChildSize: .9,
        minChildSize: .3,
        builder: (context, controller) => Material(
          color: CA.canvasAlt,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: CA.edge,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(children: [
                Text('Choose widgets',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('${available.length}',
                    style: const TextStyle(color: CA.dim, fontSize: 13)),
              ]),
            ),
            Expanded(
              child: GridView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 92,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: available.length,
                itemBuilder: (context, index) {
                  final tile = available[index];
                  return _PickerTile(
                    tile: tile,
                    onTap: () => onPick(tile),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.tile, required this.onTap});

  final TileRenderer tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: CA.glass,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CA.edge),
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CA.accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(tile.icon, color: CA.accent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tile.label(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${tile.defaultSpan.w} × ${tile.defaultSpan.h}',
                      style: const TextStyle(fontSize: 12, color: CA.dim),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}
