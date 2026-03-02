import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'settings/about_tab.dart';
import 'settings/display_tab.dart';
import 'settings/logs_tab.dart';
import 'settings/peers_tab.dart';
import 'settings/prompts_tab.dart';
import 'settings/server_tab.dart';
import 'settings/system_tab.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 7,
      vsync: this,
      animationDuration: Duration.zero,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = S.of(context);
        final padding = Responsive.pagePadding(Responsive.of(constraints.maxWidth));
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.settingsHeading,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 24),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.accent,
                labelColor: AppColors.text,
                unselectedLabelColor: AppColors.textMuted,
                dividerColor: AppColors.border,
                tabs: [
                  Tab(text: s.tabServer),
                  Tab(text: s.tabLogs),
                  Tab(text: s.tabPeers),
                  Tab(text: s.tabPrompts),
                  Tab(text: s.tabDisplay),
                  Tab(text: s.tabAbout),
                  Tab(text: s.tabSystem),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    ServerTab(apiClient: widget.apiClient),
                    LogsTab(apiClient: widget.apiClient),
                    PeersTab(apiClient: widget.apiClient),
                    PromptsTab(apiClient: widget.apiClient),
                    DisplayTab(apiClient: widget.apiClient),
                    AboutTab(apiClient: widget.apiClient),
                    const SystemTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
