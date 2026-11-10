import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets/registry.dart';
import '../widgets/tile_contract.dart';

/// Placement of a single tile inside the grid, in grid cells.
@immutable
class GridPlacement {
  final int index;
  final int column;
  final int row;
  final int columns;
  final int rows;

  const GridPlacement({
    required this.index,
    required this.column,
    required this.row,
    required this.columns,
    required this.rows,
  });

  bool overlaps(GridPlacement other) =>
      column < other.column + other.columns &&
      other.column < column + columns &&
      row < other.row + other.rows &&
      other.row < row + rows;
}

/// Pure layout engine: assigns every tile a non-overlapping rectangle.
///
/// The engine is deliberately free of widget code so placement can be
/// unit-tested directly.
class GridLayout {
  /// Number of grid columns used on a given surface.
  static int columnsFor(Surface surface) =>
      surface == Surface.car ? 12 : 8;

  /// Computes placements for [tiles] on a [columns]-wide grid.
  ///
  /// Tiles are placed in list order using a first-fit strategy: the first
  /// free rectangle that fits the tile's span is used, so no two tiles ever
  /// overlap. A tile wider than the grid is clamped to the grid width.
  static List<GridPlacement> place(
    List<TilePlacement> tiles,
    int columns, {
    Map<String, SizeSpan> minSpans = const {},
    Map<String, SizeSpan> maxSpans = const {},
  }) {
    final placements = <GridPlacement>[];
    final occupied = <GridPlacement>[];

    for (var i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      final renderer = tileById(tile.id);
      final min = minSpans[tile.id] ?? renderer?.minSpan;
      final max = maxSpans[tile.id] ?? renderer?.maxSpan;

      var w = tile.span.w;
      var h = tile.span.h;
      if (min != null) {
        w = w < min.w ? min.w : w;
        h = h < min.h ? min.h : h;
      }
      if (max != null) {
        w = w > max.w ? max.w : w;
        h = h > max.h ? max.h : h;
      }
      if (w > columns) w = columns;
      if (w < 1) w = 1;
      if (h < 1) h = 1;

      GridPlacement? candidate;
      for (var row = 0; candidate == null; row++) {
        for (var column = 0; column + w <= columns; column++) {
          final c = GridPlacement(
              index: i, column: column, row: row, columns: w, rows: h);
          if (occupied.every((o) => !o.overlaps(c))) {
            candidate = c;
            break;
          }
        }
      }
      occupied.add(candidate);
      placements.add(candidate);
    }
    return placements;
  }

  /// Total number of grid rows used by [placements].
  static int rowCount(List<GridPlacement> placements) {
    if (placements.isEmpty) return 0;
    var rows = 0;
    for (final p in placements) {
      final end = p.row + p.rows;
      if (end > rows) rows = end;
    }
    return rows;
  }
}

/// Responsive dashboard grid of widget tiles.
///
/// Landscape/car layout uses 12 columns, portrait 8. Rows are square-ish:
/// each row is as tall as a cell is wide, so tiles keep a pleasing aspect.
class DashboardGrid extends StatelessWidget {
  const DashboardGrid({
    super.key,
    required this.tiles,
    required this.surface,
    required this.payloads,
    this.editing = false,
    this.onLayoutChanged,
    this.onTileTap,
    this.onAdd,
  });

  final List<TilePlacement> tiles;
  final Surface surface;
  final Map<String, dynamic> payloads;
  final bool editing;
  final void Function(List<TilePlacement> next)? onLayoutChanged;
  final void Function(String tileId)? onTileTap;
  final VoidCallback? onAdd;

  static const double gap = 10;

  @override
  Widget build(BuildContext context) {
    final columns = GridLayout.columnsFor(surface);
    final placements = GridLayout.place(tiles, columns);
    final rows = GridLayout.rowCount(placements);
    if (tiles.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.dashboard_customize_outlined,
              size: 40, color: CA.dim),
          const SizedBox(height: 10),
          const Text('No widgets yet',
              style: TextStyle(color: CA.dim, fontSize: 14)),
          if (onAdd != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add widget'),
              ),
            ),
        ]),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final cellWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
      final cellHeight = cellWidth;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var row = 0; row < rows; row++)
              Padding(
                padding: EdgeInsets.only(bottom: row == rows - 1 ? 0 : gap),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in placements.where((p) => p.row == row)) ...[
                      SizedBox(
                        width: cellWidth * p.columns + gap * (p.columns - 1),
                        height: cellHeight * p.rows + gap * (p.rows - 1),
                        child: _TileSlot(
                          placement: p,
                          cellWidth: cellWidth,
                          cellHeight: cellHeight,
                          columns: columns,
                          tiles: tiles,
                          surface: surface,
                          payloads: payloads,
                          editing: editing,
                          onLayoutChanged: onLayoutChanged,
                          onTileTap: onTileTap,
                        ),
                      ),
                      if (p != placements.where((p) => p.row == row).last)
                        const SizedBox(width: gap),
                    ],
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _TileSlot extends StatelessWidget {
  const _TileSlot({
    required this.placement,
    required this.cellWidth,
    required this.cellHeight,
    required this.columns,
    required this.tiles,
    required this.surface,
    required this.payloads,
    required this.editing,
    required this.onLayoutChanged,
    required this.onTileTap,
  });

  final GridPlacement placement;
  final double cellWidth;
  final double cellHeight;
  final int columns;
  final List<TilePlacement> tiles;
  final Surface surface;
  final Map<String, dynamic> payloads;
  final bool editing;
  final void Function(List<TilePlacement> next)? onLayoutChanged;
  final void Function(String tileId)? onTileTap;

  @override
  Widget build(BuildContext context) {
    final tile = tiles[placement.index];
    final renderer = tileById(tile.id);
    if (renderer == null) return const SizedBox.shrink();

    final ctx = TileContext(
      now: DateTime.now(),
      surface: surface,
      config: tile.config,
      payloads: payloads,
      onConfigChanged: (next) {
        onLayoutChanged?.call([
          for (final t in tiles)
            t.id == tile.id ? t.copyWith(config: next) : t,
        ]);
      },
      onRemove: (_) {
        onLayoutChanged?.call(tiles.where((t) => t.id != tile.id).toList());
      },
    );

    Widget child = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: renderer.build(context, ctx),
    );

    if (editing) {
      child = Stack(children: [
        Positioned.fill(child: child),
        Positioned(
          right: 0,
          top: 0,
          child: _RemoveButton(
            onPressed: () => onLayoutChanged
                ?.call(tiles.where((t) => t.id != tile.id).toList()),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 2,
          child: _ResizeHandle(
            onDelta: (dx, dy) {
              final next = SizeSpan(
                (tile.span.w + dx).clamp(1, columns),
                (tile.span.h + dy).clamp(1, 12),
              );
              onLayoutChanged?.call([
                for (final t in tiles)
                  t.id == tile.id ? t.copyWith(span: next) : t,
              ]);
            },
          ),
        ),
      ]);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTileTap?.call(tile.id),
      child: child,
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _RemoveButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.close, size: 18, color: CA.ink),
          ),
        ),
      );
}

class _ResizeHandle extends StatefulWidget {
  final void Function(int dx, int dy) onDelta;
  const _ResizeHandle({required this.onDelta});

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  int _dx = 0;
  int _dy = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _dx += details.delta.dx > 12
                ? 1
                : (details.delta.dx < -12 ? -1 : 0);
            _dy += details.delta.dy > 12
                ? 1
                : (details.delta.dy < -12 ? -1 : 0);
          });
          if (_dx != 0 || _dy != 0) {
            widget.onDelta(_dx, _dy);
            _dx = 0;
            _dy = 0;
          }
        },
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.open_in_full, size: 18, color: CA.accent),
        ),
      );
}
