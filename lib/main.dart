import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/dashboard_controller.dart';
import 'app/strings.dart';
import 'features/about_screen.dart';
import 'features/dashboard.dart';
import 'features/settings_screen.dart';
import 'features/widget_picker.dart';
import 'projection/car_surface.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/registry.dart';
import 'widgets/tile_contract.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(CruiseAssistApp(store: store));
}

class CruiseAssistApp extends StatefulWidget {
  final AppStore store;
  const CruiseAssistApp({super.key, required this.store});

  @override
  State<CruiseAssistApp> createState() => _CruiseAssistAppState();
}

class _CruiseAssistAppState extends State<CruiseAssistApp> {
  late final DashboardController _controller =
      DashboardController(store: widget.store);

  @override
  void initState() {
    super.initState();
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final s = widget.store.settings;
        return MaterialApp(
          title: 'Cruise Assist',
          debugShowCheckedModeBanner: false,
          theme: CA.dark(),
          darkTheme: CA.dark(),
          themeMode: ThemeMode.dark,
          locale: Locale(s.language),
          supportedLocales: const [Locale('en'), Locale('ms')],
          localizationsDelegates: const [
            LDelegate(),
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          builder: (context, child) {
            // One global text-scale knob: the car surface needs generous type
            // and the phone benefits from the same switch.
            final scale = s.largeText ? 1.18 : 1.0;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            );
          },
          home: HomeShell(store: widget.store, controller: _controller),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  final AppStore store;
  final DashboardController controller;
  const HomeShell({
    super.key,
    required this.store,
    required this.controller,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  AppStore get _store => widget.store;

  Surface get _surface =>
      MediaQuery.sizeOf(context).width >= 720 ? Surface.car : Surface.phone;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final body = switch (_index) {
      1 => _editPage(),
      2 => SettingsScreen(store: _store),
      3 => CarScreenPage(controller: widget.controller),
      4 => AboutScreen(store: _store),
      _ => _dashboardPage(),
    };

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1000,
              backgroundColor: CA.canvasAlt,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: _railDestinations(context),
            ),
            const VerticalDivider(width: 1, color: CA.edge),
            Expanded(child: SafeArea(child: body)),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        backgroundColor: CA.canvasAlt,
        indicatorColor: CA.accent.withValues(alpha: 0.18),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _barDestinations(context),
      ),
    );
  }

  static const _icons = [
    Icons.grid_view_outlined,
    Icons.dashboard_customize_outlined,
    Icons.tune_outlined,
    Icons.directions_car_outlined,
    Icons.info_outline,
  ];
  static const _iconsSelected = [
    Icons.grid_view,
    Icons.dashboard_customize,
    Icons.tune,
    Icons.directions_car,
    Icons.info,
  ];
  static const _labels = [
    'tab.dashboard',
    'tab.edit',
    'tab.settings',
    'tab.project',
    'tab.about',
  ];

  List<NavigationRailDestination> _railDestinations(BuildContext context) => [
        for (var i = 0; i < _labels.length; i++)
          NavigationRailDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_iconsSelected[i]),
            label: Text(context.t(_labels[i])),
          ),
      ];

  List<NavigationDestination> _barDestinations(BuildContext context) => [
        for (var i = 0; i < _labels.length; i++)
          NavigationDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_iconsSelected[i]),
            label: context.t(_labels[i]),
          ),
      ];

  Widget _dashboardPage() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => RefreshIndicator(
        color: CA.accent,
        onRefresh: widget.controller.refreshAll,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _TopBar(
              controller: widget.controller,
              onRefresh: widget.controller.refreshAll,
            ),
            DashboardGrid(
              tiles: _store.layout,
              surface: _surface,
              payloads: widget.controller.payloads,
              editing: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _editPage() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => DashboardGrid(
        tiles: _store.layout,
        surface: _surface,
        payloads: widget.controller.payloads,
        editing: true,
        onLayoutChanged: _store.setLayout,
        onAdd: _showPicker,
      ),
    );
  }

  Future<void> _showPicker() async {
    final existing = _store.layout.map((e) => e.id).toSet();
    final available = allTiles().where((t) => !existing.contains(t.id)).toList();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CA.canvasAlt,
      isScrollControlled: true,
      builder: (ctx) => WidgetPickerSheet(
        available: available,
        onPick: (t) {
          _store.addTile(t.id, t.defaultSpan);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final DashboardController controller;
  final Future<void> Function() onRefresh;
  const _TopBar({required this.controller, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.directions_car_filled, color: CA.accent, size: 26),
          const SizedBox(width: 10),
          Text(
            context.t('app.name'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (controller.busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CA.accent,
                ),
              ),
            )
          else
            IconButton(
              tooltip: context.t('action.refresh'),
              onPressed: () {
                HapticFeedback.selectionClick();
                onRefresh();
              },
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    );
  }
}
