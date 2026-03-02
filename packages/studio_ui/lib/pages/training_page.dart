import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'training/dataset_tab.dart';
import 'training/training_tab.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
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
            s.trainingHeading,
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
              Tab(text: s.tabDataset),
              Tab(text: s.tabTraining),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                DatasetTab(apiClient: widget.apiClient),
                TrainingTab(apiClient: widget.apiClient),
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
