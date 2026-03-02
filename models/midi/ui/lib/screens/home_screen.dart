import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/picked_file.dart';
import '../models/task_status.dart';
import '../providers/api_client_provider.dart';
import '../providers/edit_file_provider.dart';
import '../providers/pipeline_jobs_provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_banner.dart';
import '../widgets/mini_player.dart';
import '../widgets/pipeline_job_card.dart';
import 'generate/multi_track_tab.dart';
import 'edit/extend_tab.dart';
import 'pipeline/data_tab.dart';
import 'pipeline/pretokenize_tab.dart';
import 'pipeline/training_tab.dart';
import 'pipeline/diagnosis_tab.dart';
import 'history/history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTab = 0;

  /// Tab indices for pipeline tabs that show jobs on the right panel.
  static const _kDataTab = 2;
  static const _kPretokenizeTab = 3;
  static const _kTrainingTab = 4;
  static const _kDiagnosisTab = 5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTab) {
        setState(() => _currentTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _switchToExtendTab(TaskStatus task) async {
    try {
      final api = ref.read(apiClientProvider);
      final bytes = await api.downloadFile(task.downloadUrl!);

      ref.read(editFileProvider.notifier).state = PickedFile(
        bytes: bytes,
        name: 'extend_${task.taskId.substring(0, 8)}.mid',
      );
      _tabController.animateTo(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load for extending: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 12,
        title: Image.asset('assets/diskrot.png', height: 20),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
              child: Image.asset('assets/slashes.png', height: 24),
            ),
          ),
        ],
        backgroundColor: const Color(0xFF161616),
        foregroundColor: AppColors.text,
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: Row(
              children: [
                // LEFT: Tabbed forms
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        indicatorColor: AppColors.controlBlue,
                        labelColor: AppColors.text,
                        unselectedLabelColor: AppColors.textMuted,
                        tabs: const [
                          Tab(text: 'Generate'),
                          Tab(text: 'Extend'),
                          Tab(text: 'Data'),
                          Tab(text: 'Pretokenize'),
                          Tab(text: 'Training'),
                          Tab(text: 'Diagnosis'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            MultiTrackTab(onTaskSubmitted: () {}),
                            ExtendTab(onTaskSubmitted: () {}),
                            DataTab(onTaskSubmitted: () {}),
                            PretokenizeTab(onTaskSubmitted: () {}),
                            TrainingTab(onTaskSubmitted: () {}),
                            DiagnosisTab(onTaskSubmitted: () {}),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1, color: AppColors.border),
                // RIGHT: context-dependent panel
                Expanded(
                  flex: 2,
                  child: _currentTab == _kTrainingTab ||
                          _currentTab == _kPretokenizeTab ||
                          _currentTab == _kDataTab ||
                          _currentTab == _kDiagnosisTab
                      ? _PipelineJobsPanel(
                          generationType: switch (_currentTab) {
                            _kTrainingTab => 'training',
                            _kPretokenizeTab => 'pretokenize',
                            _kDiagnosisTab => 'diagnosis',
                            _ => 'download',
                          },
                        )
                      : HistoryScreen(
                          onExtendTrack: _switchToExtendTab,
                        ),
                ),
              ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}

/// Right-side panel that shows pipeline job cards for a given generation type.
class _PipelineJobsPanel extends ConsumerWidget {
  final String generationType;

  const _PipelineJobsPanel({required this.generationType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allJobs = ref.watch(pipelineJobsProvider);
    final jobs =
        allJobs.where((t) => t.generationType == generationType).toList();

    // Ensure each job has a status stream active.
    for (final job in jobs) {
      ref.watch(taskStatusProvider(job));
    }

    final title = switch (generationType) {
      'training' => 'Training Jobs',
      'pretokenize' => 'Pretokenize Jobs',
      'diagnosis' => 'Diagnosis Jobs',
      _ => 'Data Jobs',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall,
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: jobs.isEmpty
              ? Center(
                  child: Text(
                    'No jobs yet',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return PipelineJobCard(task: jobs[index]);
                  },
                ),
        ),
      ],
    );
  }
}
