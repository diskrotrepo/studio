import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'application/now_playing.dart';
import 'audio_player/audio_controls.dart';
import 'configuration/configuration.dart';
import 'http/diskrot_http_client.dart';
import 'pages/create_page.dart';
import 'pages/lyric_book_page.dart';
import 'pages/settings_page.dart';

import 'services/api_client.dart';
import 'services/user_id_manager.dart';
import 'splash/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final diskrotHttpClient = DiskRotHttpClient(
    configuration,
    onAnonymousLoginRequired: () async {
      throw Exception('Anonymous login required');
    },
  );

  final apiClient = ApiClient(
    config: configuration,
    httpClient: diskrotHttpClient,
  );

  // Register or restore the external user ID from the backend.
  final userIdManager = await UserIdManager.initialize(apiClient);
  diskrotHttpClient.userId = userIdManager.userId;

  runApp(
    MultiProvider(
      providers: [Provider.value(value: apiClient)],
      child: const StudioApp(),
    ),
  );
}

class StudioApp extends StatefulWidget {
  const StudioApp({super.key});

  @override
  State<StudioApp> createState() => _StudioAppState();
}

class _StudioAppState extends State<StudioApp> {
  bool _splashComplete = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: _splashComplete
          ? const AppShell()
          : SplashScreen(
              onComplete: () => setState(() => _splashComplete = true),
            ),
    );
  }
}

enum NavItem { create, lyrics, settings }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  NavItem _selected = NavItem.create;
  late final ApiClient _apiClient;

  @override
  void initState() {
    super.initState();
    _apiClient = context.read<ApiClient>();
    _apiClient.refreshRemoteStatus();
    _apiClient.loadVisualizerSetting();
    _apiClient.loadWorkspaces();
    _apiClient.isRemote.addListener(_onRemoteChanged);
  }

  @override
  void dispose() {
    _apiClient.isRemote.removeListener(_onRemoteChanged);
    super.dispose();
  }

  void _onRemoteChanged() {
    setState(() {});
  }

  Widget _buildContent() {
    return switch (_selected) {
      NavItem.create => const CreatePage(),
      NavItem.lyrics => const LyricBookPage(),
      NavItem.settings => SettingsPage(
          apiClient: _apiClient,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isRemote = _apiClient.isRemote.value;
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 12,
        toolbarHeight: 40,
        title: Image.asset('assets/diskrot.png', height: 32, filterQuality: FilterQuality.high),
        actions: [
          if (isRemote)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF66BB6A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF66BB6A).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_outlined,
                      size: 14, color: Color(0xFF66BB6A)),
                  const SizedBox(width: 5),
                  Text(
                    s.remoteLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF66BB6A),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
        backgroundColor: Colors.black,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screen = Responsive.of(constraints.maxWidth);
          final sidebarW = Responsive.sidebarWidth(screen);
          final compact = screen == ScreenSize.compact;
          return Row(
            children: [
              Container(
                width: sidebarW,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    right: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _NavButton(
                      icon: Icons.music_note,
                      label: s.navCreate,
                      selected: _selected == NavItem.create,
                      accent: const Color(0xFFEC407A),
                      compact: compact,
                      onTap: () => setState(() {
                        _selected = NavItem.create;
                      }),
                    ),
                    _NavButton(
                      icon: Icons.menu_book,
                      label: s.navLyrics,
                      selected: _selected == NavItem.lyrics,
                      accent: const Color(0xFFAB47BC),
                      compact: compact,
                      onTap: () => setState(() {
                        _selected = NavItem.lyrics;
                      }),
                    ),
                    _NavButton(
                      icon: Icons.settings_outlined,
                      label: s.navSettings,
                      selected: _selected == NavItem.settings,
                      accent: const Color(0xFF00ACC1),
                      compact: compact,
                      onTap: () => setState(() {
                        _selected = NavItem.settings;
                      }),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildContent()),
            ],
          );
        },
      ),
      bottomNavigationBar: ValueListenableBuilder<PlayingTrack?>(
        valueListenable: NowPlaying.instance.track,
        builder: (context, track, _) {
          if (track == null) return const SizedBox.shrink();
          return Container(
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const AudioControls(),
          );
        },
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovered;
    final iconColor = active ? widget.accent : AppColors.textMuted;
    final labelColor = widget.selected
        ? widget.accent
        : (_hovered
              ? widget.accent.withValues(alpha: 0.85)
              : AppColors.textMuted);

    final compact = widget.compact;
    final btnWidth = compact ? 48.0 : 72.0;
    final iconContainerSize = compact ? 30.0 : 36.0;
    final iconSize = compact ? 20.0 : 22.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: btnWidth,
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.accent.withValues(alpha: 0.10)
                : _hovered
                ? widget.accent.withValues(alpha: 0.06)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: widget.selected ? widget.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                decoration: BoxDecoration(
                  color: active
                      ? widget.accent.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, size: iconSize, color: iconColor),
              ),
              if (!compact) ...[
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: labelColor,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
