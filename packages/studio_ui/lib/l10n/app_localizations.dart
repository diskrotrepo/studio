import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get appTitle;

  /// No description provided for @remoteLabel.
  ///
  /// In en, this message translates to:
  /// **'REMOTE'**
  String get remoteLabel;

  /// No description provided for @navCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get navCreate;

  /// No description provided for @navTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get navTraining;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @buttonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get buttonCancel;

  /// No description provided for @buttonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get buttonDelete;

  /// No description provided for @buttonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get buttonSave;

  /// No description provided for @buttonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get buttonSelect;

  /// No description provided for @buttonGenerate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get buttonGenerate;

  /// No description provided for @buttonUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get buttonUpload;

  /// No description provided for @buttonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get buttonEdit;

  /// No description provided for @buttonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get buttonClear;

  /// No description provided for @buttonActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get buttonActivate;

  /// No description provided for @buttonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get buttonReset;

  /// No description provided for @buttonUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get buttonUpdate;

  /// No description provided for @tooltipPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get tooltipPrevious;

  /// No description provided for @tooltipPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get tooltipPlay;

  /// No description provided for @tooltipPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get tooltipPause;

  /// No description provided for @tooltipNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tooltipNext;

  /// No description provided for @tooltipLoop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get tooltipLoop;

  /// No description provided for @tooltipShowQueue.
  ///
  /// In en, this message translates to:
  /// **'Show Queue'**
  String get tooltipShowQueue;

  /// No description provided for @tooltipQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get tooltipQueue;

  /// No description provided for @tooltipNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get tooltipNew;

  /// No description provided for @tooltipSortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort order'**
  String get tooltipSortOrder;

  /// No description provided for @tooltipFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get tooltipFilter;

  /// No description provided for @tooltipLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get tooltipLike;

  /// No description provided for @tooltipDislike.
  ///
  /// In en, this message translates to:
  /// **'Dislike'**
  String get tooltipDislike;

  /// No description provided for @tooltipDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get tooltipDownload;

  /// No description provided for @tooltipDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tooltipDelete;

  /// No description provided for @tooltipRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get tooltipRefresh;

  /// No description provided for @tooltipRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get tooltipRemove;

  /// No description provided for @tooltipCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied!'**
  String get tooltipCopied;

  /// No description provided for @tooltipCopyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get tooltipCopyToClipboard;

  /// No description provided for @tooltipBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse...'**
  String get tooltipBrowse;

  /// No description provided for @tooltipNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get tooltipNowPlaying;

  /// No description provided for @tooltipGenerateWithAi.
  ///
  /// In en, this message translates to:
  /// **'Generate {text} with AI'**
  String tooltipGenerateWithAi(String text);

  /// No description provided for @tooltipSourceClipRequired.
  ///
  /// In en, this message translates to:
  /// **'A source clip is required for {taskType}'**
  String tooltipSourceClipRequired(String taskType);

  /// No description provided for @queueTitle.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queueTitle;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your queue is empty'**
  String get queueEmpty;

  /// No description provided for @dialogSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get dialogSelectFile;

  /// No description provided for @dialogSelectDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select Directory'**
  String get dialogSelectDirectory;

  /// No description provided for @noMatchingFiles.
  ///
  /// In en, this message translates to:
  /// **'No matching files'**
  String get noMatchingFiles;

  /// No description provided for @noSubdirectories.
  ///
  /// In en, this message translates to:
  /// **'No subdirectories'**
  String get noSubdirectories;

  /// No description provided for @settingsHeading.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsHeading;

  /// No description provided for @tabServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get tabServer;

  /// No description provided for @tabLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get tabLogs;

  /// No description provided for @tabPeers.
  ///
  /// In en, this message translates to:
  /// **'Peers'**
  String get tabPeers;

  /// No description provided for @tabPrompts.
  ///
  /// In en, this message translates to:
  /// **'Prompts'**
  String get tabPrompts;

  /// No description provided for @tabDisplay.
  ///
  /// In en, this message translates to:
  /// **'Visualizers'**
  String get tabDisplay;

  /// No description provided for @tabAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get tabAbout;

  /// No description provided for @tabSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get tabSystem;

  /// No description provided for @trainingHeading.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get trainingHeading;

  /// No description provided for @tabDataset.
  ///
  /// In en, this message translates to:
  /// **'Dataset'**
  String get tabDataset;

  /// No description provided for @tabTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get tabTraining;

  /// No description provided for @serverAllowConnections.
  ///
  /// In en, this message translates to:
  /// **'Allow Connections'**
  String get serverAllowConnections;

  /// No description provided for @serverAllowConnectionsDescription.
  ///
  /// In en, this message translates to:
  /// **'When enabled, peers can connect to this server'**
  String get serverAllowConnectionsDescription;

  /// No description provided for @serverEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get serverEnvironment;

  /// No description provided for @serverBackends.
  ///
  /// In en, this message translates to:
  /// **'Server Backends'**
  String get serverBackends;

  /// No description provided for @serverLabelBuild.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get serverLabelBuild;

  /// No description provided for @serverLabelApiHost.
  ///
  /// In en, this message translates to:
  /// **'API Host'**
  String get serverLabelApiHost;

  /// No description provided for @serverLabelSecure.
  ///
  /// In en, this message translates to:
  /// **'Secure'**
  String get serverLabelSecure;

  /// No description provided for @serverLabelHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get serverLabelHost;

  /// No description provided for @serverLabelProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get serverLabelProtocol;

  /// No description provided for @serverLabelStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get serverLabelStatus;

  /// No description provided for @serverStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get serverStatusActive;

  /// No description provided for @serverStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get serverStatusInactive;

  /// No description provided for @serverNoBackends.
  ///
  /// In en, this message translates to:
  /// **'No server backends configured.'**
  String get serverNoBackends;

  /// No description provided for @serverActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} (active)'**
  String serverActiveLabel(String name);

  /// No description provided for @buttonAddServer.
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get buttonAddServer;

  /// No description provided for @dialogEditServer.
  ///
  /// In en, this message translates to:
  /// **'Edit Server'**
  String get dialogEditServer;

  /// No description provided for @dialogAddServer.
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get dialogAddServer;

  /// No description provided for @labelName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get labelName;

  /// No description provided for @labelApiHost.
  ///
  /// In en, this message translates to:
  /// **'API Host'**
  String get labelApiHost;

  /// No description provided for @hintLocalhost.
  ///
  /// In en, this message translates to:
  /// **'localhost:8080'**
  String get hintLocalhost;

  /// No description provided for @labelHttps.
  ///
  /// In en, this message translates to:
  /// **'HTTPS'**
  String get labelHttps;

  /// No description provided for @buttonTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get buttonTestConnection;

  /// No description provided for @testingConnection.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get testingConnection;

  /// No description provided for @healthHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get healthHealthy;

  /// No description provided for @healthUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get healthUnreachable;

  /// No description provided for @logsHeading.
  ///
  /// In en, this message translates to:
  /// **'Server Logs'**
  String get logsHeading;

  /// No description provided for @infoLogs.
  ///
  /// In en, this message translates to:
  /// **'Recent log output from the server process'**
  String get infoLogs;

  /// No description provided for @logsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No log entries.'**
  String get logsEmpty;

  /// No description provided for @peersHeading.
  ///
  /// In en, this message translates to:
  /// **'Peer Connections'**
  String get peersHeading;

  /// No description provided for @infoPeers.
  ///
  /// In en, this message translates to:
  /// **'Peers are other Studio instances that have connected to this server. You can block a peer to reject its requests.'**
  String get infoPeers;

  /// No description provided for @peersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No peer connections yet.'**
  String get peersEmpty;

  /// No description provided for @peerBlocked.
  ///
  /// In en, this message translates to:
  /// **'BLOCKED'**
  String get peerBlocked;

  /// No description provided for @buttonBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get buttonBlock;

  /// No description provided for @buttonUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get buttonUnblock;

  /// No description provided for @peerFirstSeen.
  ///
  /// In en, this message translates to:
  /// **'First seen'**
  String get peerFirstSeen;

  /// No description provided for @peerLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get peerLastSeen;

  /// No description provided for @peerRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get peerRequests;

  /// No description provided for @promptsHeading.
  ///
  /// In en, this message translates to:
  /// **'AI System Prompts'**
  String get promptsHeading;

  /// No description provided for @infoPrompts.
  ///
  /// In en, this message translates to:
  /// **'Custom system prompts sent to the LLM when generating lyrics or audio descriptions. Leave blank to use defaults.'**
  String get infoPrompts;

  /// No description provided for @promptsAudioModel.
  ///
  /// In en, this message translates to:
  /// **'Audio model'**
  String get promptsAudioModel;

  /// No description provided for @promptsLyricsGeneration.
  ///
  /// In en, this message translates to:
  /// **'Lyrics generation'**
  String get promptsLyricsGeneration;

  /// No description provided for @promptsAudioPromptGeneration.
  ///
  /// In en, this message translates to:
  /// **'Audio prompt generation'**
  String get promptsAudioPromptGeneration;

  /// No description provided for @promptsSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved.'**
  String get promptsSettingsSaved;

  /// No description provided for @displayVisualizerHeading.
  ///
  /// In en, this message translates to:
  /// **'Visualizer'**
  String get displayVisualizerHeading;

  /// No description provided for @displayVisualizerDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the visualizer style for cover art.'**
  String get displayVisualizerDescription;

  /// No description provided for @visualizerCreamdrop.
  ///
  /// In en, this message translates to:
  /// **'Creamdrop'**
  String get visualizerCreamdrop;

  /// No description provided for @visualizerCreamdropDescription.
  ///
  /// In en, this message translates to:
  /// **'Swirling fractal plasma with domain-warped noise.'**
  String get visualizerCreamdropDescription;

  /// No description provided for @visualizerWaveform.
  ///
  /// In en, this message translates to:
  /// **'Waveform'**
  String get visualizerWaveform;

  /// No description provided for @visualizerWaveformDescription.
  ///
  /// In en, this message translates to:
  /// **'Concentric rings and petals pulsing with audio.'**
  String get visualizerWaveformDescription;

  /// No description provided for @visualizerSpectrum.
  ///
  /// In en, this message translates to:
  /// **'Spectrum'**
  String get visualizerSpectrum;

  /// No description provided for @visualizerSpectrumDescription.
  ///
  /// In en, this message translates to:
  /// **'Explosive color fields driven by frequency bands.'**
  String get visualizerSpectrumDescription;

  /// No description provided for @displaySettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved.'**
  String get displaySettingsSaved;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @aboutCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get aboutCredits;

  /// No description provided for @aboutStudioBy.
  ///
  /// In en, this message translates to:
  /// **'s t u d i o by '**
  String get aboutStudioBy;

  /// No description provided for @aboutDiskrot.
  ///
  /// In en, this message translates to:
  /// **'diskrot'**
  String get aboutDiskrot;

  /// No description provided for @aboutSourceOnGithub.
  ///
  /// In en, this message translates to:
  /// **'source on GitHub'**
  String get aboutSourceOnGithub;

  /// No description provided for @aboutServerPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Server Public Key'**
  String get aboutServerPublicKey;

  /// No description provided for @aboutBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get aboutBranch;

  /// No description provided for @createHeading.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createHeading;

  /// No description provided for @labelModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get labelModel;

  /// No description provided for @modelAceStep.
  ///
  /// In en, this message translates to:
  /// **'ACE Step 1.5'**
  String get modelAceStep;

  /// No description provided for @modelBark.
  ///
  /// In en, this message translates to:
  /// **'Bark'**
  String get modelBark;

  /// No description provided for @labelTaskType.
  ///
  /// In en, this message translates to:
  /// **'Task Type'**
  String get labelTaskType;

  /// No description provided for @labelTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get labelTitle;

  /// No description provided for @hintSongTitle.
  ///
  /// In en, this message translates to:
  /// **'Song title...'**
  String get hintSongTitle;

  /// No description provided for @labelLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get labelLyrics;

  /// No description provided for @hintEnterLyrics.
  ///
  /// In en, this message translates to:
  /// **'Enter lyrics...'**
  String get hintEnterLyrics;

  /// No description provided for @labelPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get labelPrompt;

  /// No description provided for @labelGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get labelGenres;

  /// No description provided for @hintSearchGenres.
  ///
  /// In en, this message translates to:
  /// **'Type to search genres...'**
  String get hintSearchGenres;

  /// No description provided for @hintDescribeStyle.
  ///
  /// In en, this message translates to:
  /// **'Describe the style, mood, genre...'**
  String get hintDescribeStyle;

  /// No description provided for @labelAvoid.
  ///
  /// In en, this message translates to:
  /// **'Avoid'**
  String get labelAvoid;

  /// No description provided for @hintDescribeAvoid.
  ///
  /// In en, this message translates to:
  /// **'Describe what to avoid...'**
  String get hintDescribeAvoid;

  /// No description provided for @noTasksYet.
  ///
  /// In en, this message translates to:
  /// **'No songs found'**
  String get noTasksYet;

  /// No description provided for @backToTasks.
  ///
  /// In en, this message translates to:
  /// **'Back to tasks'**
  String get backToTasks;

  /// No description provided for @tooltipMoveWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Move to workspace'**
  String get tooltipMoveWorkspace;

  /// No description provided for @movedToWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Moved to {name}'**
  String movedToWorkspace(String name);

  /// No description provided for @dialogMoveToWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to Workspace'**
  String get dialogMoveToWorkspaceTitle;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterLiked.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get filterLiked;

  /// No description provided for @filterDisliked.
  ///
  /// In en, this message translates to:
  /// **'Disliked'**
  String get filterDisliked;

  /// No description provided for @sortNewestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewestFirst;

  /// No description provided for @sortOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sortOldestFirst;

  /// No description provided for @buttonUnselect.
  ///
  /// In en, this message translates to:
  /// **'Unselect'**
  String get buttonUnselect;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @buttonMoveCount.
  ///
  /// In en, this message translates to:
  /// **'Move ({count})'**
  String buttonMoveCount(int count);

  /// No description provided for @buttonDeleteCount.
  ///
  /// In en, this message translates to:
  /// **'Delete ({count})'**
  String buttonDeleteCount(int count);

  /// No description provided for @dialogDeleteSongsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Songs'**
  String get dialogDeleteSongsTitle;

  /// No description provided for @dialogDeleteSongsContent.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} selected {count, plural, =1{song} other{songs}}? This action cannot be undone.'**
  String dialogDeleteSongsContent(int count);

  /// No description provided for @dialogDeleteSongTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Song'**
  String get dialogDeleteSongTitle;

  /// No description provided for @dialogDeleteSongContent.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get dialogDeleteSongContent;

  /// No description provided for @detailsHeading.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detailsHeading;

  /// No description provided for @noLyrics.
  ///
  /// In en, this message translates to:
  /// **'No lyrics'**
  String get noLyrics;

  /// No description provided for @snackbarLyricsCopied.
  ///
  /// In en, this message translates to:
  /// **'Lyrics copied'**
  String get snackbarLyricsCopied;

  /// No description provided for @snackbarDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get snackbarDownloadComplete;

  /// No description provided for @snackbarFailedGenerateLyrics.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate lyrics: {error}'**
  String snackbarFailedGenerateLyrics(String error);

  /// No description provided for @snackbarFailedGeneratePrompt.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate prompt: {error}'**
  String snackbarFailedGeneratePrompt(String error);

  /// No description provided for @errorSelectAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Please select an audio file first'**
  String get errorSelectAudioFile;

  /// No description provided for @labelCopied.
  ///
  /// In en, this message translates to:
  /// **'{label} copied'**
  String labelCopied(String label);

  /// No description provided for @labelCreativity.
  ///
  /// In en, this message translates to:
  /// **'Creativity'**
  String get labelCreativity;

  /// No description provided for @subtitleCreativity.
  ///
  /// In en, this message translates to:
  /// **'Predictable to surprising'**
  String get subtitleCreativity;

  /// No description provided for @infoCreativity.
  ///
  /// In en, this message translates to:
  /// **'Controls how unpredictable the output is. Low values produce safer, more conventional results. High values make the AI take bigger creative risks.'**
  String get infoCreativity;

  /// No description provided for @labelPromptStrength.
  ///
  /// In en, this message translates to:
  /// **'Prompt Strength'**
  String get labelPromptStrength;

  /// No description provided for @subtitlePromptStrength.
  ///
  /// In en, this message translates to:
  /// **'How closely it follows your description'**
  String get subtitlePromptStrength;

  /// No description provided for @infoPromptStrength.
  ///
  /// In en, this message translates to:
  /// **'How literally the AI follows your text prompt. Higher values stick closely to what you described. Lower values give the AI more freedom to interpret.'**
  String get infoPromptStrength;

  /// No description provided for @labelQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get labelQuality;

  /// No description provided for @subtitleQuality.
  ///
  /// In en, this message translates to:
  /// **'Higher = better but slower'**
  String get subtitleQuality;

  /// No description provided for @infoQuality.
  ///
  /// In en, this message translates to:
  /// **'Number of processing steps. More steps generally produce cleaner, higher-fidelity audio but take longer to generate.'**
  String get infoQuality;

  /// No description provided for @labelDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get labelDuration;

  /// No description provided for @subtitleDuration.
  ///
  /// In en, this message translates to:
  /// **'Length of generated audio'**
  String get subtitleDuration;

  /// No description provided for @infoDuration.
  ///
  /// In en, this message translates to:
  /// **'How long the generated audio clip will be, in seconds.'**
  String get infoDuration;

  /// No description provided for @labelVariations.
  ///
  /// In en, this message translates to:
  /// **'Variations'**
  String get labelVariations;

  /// No description provided for @subtitleVariations.
  ///
  /// In en, this message translates to:
  /// **'Number of versions to create'**
  String get subtitleVariations;

  /// No description provided for @infoVariations.
  ///
  /// In en, this message translates to:
  /// **'Generates multiple different versions from the same prompt so you can pick your favorite.'**
  String get infoVariations;

  /// No description provided for @labelCfgScale.
  ///
  /// In en, this message translates to:
  /// **'CFG Scale'**
  String get labelCfgScale;

  /// No description provided for @subtitleCfgScale.
  ///
  /// In en, this message translates to:
  /// **'Classifier-free guidance strength'**
  String get subtitleCfgScale;

  /// No description provided for @infoCfgScale.
  ///
  /// In en, this message translates to:
  /// **'Balances prompt-following vs. audio quality. Too low ignores your prompt; too high can distort the sound.'**
  String get infoCfgScale;

  /// No description provided for @labelTopP.
  ///
  /// In en, this message translates to:
  /// **'Top P'**
  String get labelTopP;

  /// No description provided for @subtitleTopP.
  ///
  /// In en, this message translates to:
  /// **'Nucleus sampling threshold'**
  String get subtitleTopP;

  /// No description provided for @infoTopP.
  ///
  /// In en, this message translates to:
  /// **'Limits the AI to only the most likely choices at each step. Lower values are more focused and predictable; higher values allow more variety.'**
  String get infoTopP;

  /// No description provided for @labelRepetitionPenalty.
  ///
  /// In en, this message translates to:
  /// **'Repetition Penalty'**
  String get labelRepetitionPenalty;

  /// No description provided for @subtitleRepetitionPenalty.
  ///
  /// In en, this message translates to:
  /// **'Penalize repeated patterns'**
  String get subtitleRepetitionPenalty;

  /// No description provided for @infoRepetitionPenalty.
  ///
  /// In en, this message translates to:
  /// **'Discourages the AI from repeating the same musical phrases. Higher values push for more variation throughout the track.'**
  String get infoRepetitionPenalty;

  /// No description provided for @labelShift.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get labelShift;

  /// No description provided for @subtitleShift.
  ///
  /// In en, this message translates to:
  /// **'Audio shift amount'**
  String get subtitleShift;

  /// No description provided for @infoShift.
  ///
  /// In en, this message translates to:
  /// **'Adjusts the noise schedule during generation. Higher values can change the tonal character and texture of the output.'**
  String get infoShift;

  /// No description provided for @labelCfgIntervalStart.
  ///
  /// In en, this message translates to:
  /// **'CFG Interval Start'**
  String get labelCfgIntervalStart;

  /// No description provided for @subtitleCfgIntervalStart.
  ///
  /// In en, this message translates to:
  /// **'When guidance begins'**
  String get subtitleCfgIntervalStart;

  /// No description provided for @infoCfgIntervalStart.
  ///
  /// In en, this message translates to:
  /// **'The point in generation when prompt guidance kicks in. 0 means from the very start; higher values let early steps run freely.'**
  String get infoCfgIntervalStart;

  /// No description provided for @labelCfgIntervalEnd.
  ///
  /// In en, this message translates to:
  /// **'CFG Interval End'**
  String get labelCfgIntervalEnd;

  /// No description provided for @subtitleCfgIntervalEnd.
  ///
  /// In en, this message translates to:
  /// **'When guidance stops'**
  String get subtitleCfgIntervalEnd;

  /// No description provided for @infoCfgIntervalEnd.
  ///
  /// In en, this message translates to:
  /// **'The point in generation when prompt guidance turns off. 1 means guidance runs until the end; lower values let final steps refine freely.'**
  String get infoCfgIntervalEnd;

  /// No description provided for @labelThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get labelThinking;

  /// No description provided for @subtitleThinking.
  ///
  /// In en, this message translates to:
  /// **'Enable extended thinking'**
  String get subtitleThinking;

  /// No description provided for @infoThinking.
  ///
  /// In en, this message translates to:
  /// **'Lets the AI reason about your prompt before generating. Can improve results for complex descriptions but adds processing time.'**
  String get infoThinking;

  /// No description provided for @labelConstrainedDecoding.
  ///
  /// In en, this message translates to:
  /// **'Constrained Decoding'**
  String get labelConstrainedDecoding;

  /// No description provided for @subtitleConstrainedDecoding.
  ///
  /// In en, this message translates to:
  /// **'Enable constrained decoding'**
  String get subtitleConstrainedDecoding;

  /// No description provided for @infoConstrainedDecoding.
  ///
  /// In en, this message translates to:
  /// **'Forces the AI to follow stricter musical rules during generation. Produces more structured output but may limit creative surprises.'**
  String get infoConstrainedDecoding;

  /// No description provided for @labelRandomSeed.
  ///
  /// In en, this message translates to:
  /// **'Random Seed'**
  String get labelRandomSeed;

  /// No description provided for @subtitleRandomSeed.
  ///
  /// In en, this message translates to:
  /// **'Use a random seed each run'**
  String get subtitleRandomSeed;

  /// No description provided for @infoRandomSeed.
  ///
  /// In en, this message translates to:
  /// **'When on, every generation is unique. When off, the same settings and prompt will produce the same result each time.'**
  String get infoRandomSeed;

  /// No description provided for @labelSeed.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get labelSeed;

  /// No description provided for @hintEnterNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number...'**
  String get hintEnterNumber;

  /// No description provided for @labelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get labelAdvanced;

  /// No description provided for @labelLoraScale.
  ///
  /// In en, this message translates to:
  /// **'LoRA Scale'**
  String get labelLoraScale;

  /// No description provided for @subtitleLoraScale.
  ///
  /// In en, this message translates to:
  /// **'Adapter strength'**
  String get subtitleLoraScale;

  /// No description provided for @labelLora.
  ///
  /// In en, this message translates to:
  /// **'LoRA'**
  String get labelLora;

  /// No description provided for @labelActiveAdapter.
  ///
  /// In en, this message translates to:
  /// **'Active Adapter'**
  String get labelActiveAdapter;

  /// No description provided for @buttonUnloadAll.
  ///
  /// In en, this message translates to:
  /// **'Unload All'**
  String get buttonUnloadAll;

  /// No description provided for @labelLoadNew.
  ///
  /// In en, this message translates to:
  /// **'Load New'**
  String get labelLoadNew;

  /// No description provided for @labelAvailableLoras.
  ///
  /// In en, this message translates to:
  /// **'Available LoRAs'**
  String get labelAvailableLoras;

  /// No description provided for @buttonLoadLora.
  ///
  /// In en, this message translates to:
  /// **'Load LoRA'**
  String get buttonLoadLora;

  /// No description provided for @labelSetParameters.
  ///
  /// In en, this message translates to:
  /// **'Set Parameters'**
  String get labelSetParameters;

  /// No description provided for @labelAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Audio File'**
  String get labelAudioFile;

  /// No description provided for @clickToSelectAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Click to select an audio file'**
  String get clickToSelectAudioFile;

  /// No description provided for @labelSourceClip.
  ///
  /// In en, this message translates to:
  /// **'Source Clip'**
  String get labelSourceClip;

  /// No description provided for @labelStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get labelStart;

  /// No description provided for @labelEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get labelEnd;

  /// No description provided for @hintDescribeStem.
  ///
  /// In en, this message translates to:
  /// **'Describe the stem to generate...'**
  String get hintDescribeStem;

  /// No description provided for @hintDescribeExtendStyle.
  ///
  /// In en, this message translates to:
  /// **'Describe the music style to extend with...'**
  String get hintDescribeExtendStyle;

  /// No description provided for @hintExtendLyrics.
  ///
  /// In en, this message translates to:
  /// **'[Instrumental] or write lyrics for the extension...'**
  String get hintExtendLyrics;

  /// No description provided for @hintTrackClasses.
  ///
  /// In en, this message translates to:
  /// **'vocals, drums, bass'**
  String get hintTrackClasses;

  /// No description provided for @labelRepaintStart.
  ///
  /// In en, this message translates to:
  /// **'Repaint Start'**
  String get labelRepaintStart;

  /// No description provided for @labelRepaintEnd.
  ///
  /// In en, this message translates to:
  /// **'Repaint End'**
  String get labelRepaintEnd;

  /// No description provided for @labelCropStart.
  ///
  /// In en, this message translates to:
  /// **'Crop Start'**
  String get labelCropStart;

  /// No description provided for @labelCropEnd.
  ///
  /// In en, this message translates to:
  /// **'Crop End'**
  String get labelCropEnd;

  /// No description provided for @labelFadeIn.
  ///
  /// In en, this message translates to:
  /// **'Fade In (seconds)'**
  String get labelFadeIn;

  /// No description provided for @labelFadeOut.
  ///
  /// In en, this message translates to:
  /// **'Fade Out (seconds)'**
  String get labelFadeOut;

  /// No description provided for @labelStem.
  ///
  /// In en, this message translates to:
  /// **'Stem'**
  String get labelStem;

  /// No description provided for @labelTrackClasses.
  ///
  /// In en, this message translates to:
  /// **'Track Classes'**
  String get labelTrackClasses;

  /// No description provided for @dropToSetSourceClip.
  ///
  /// In en, this message translates to:
  /// **'Drop to set source clip'**
  String get dropToSetSourceClip;

  /// No description provided for @dragAndDropClip.
  ///
  /// In en, this message translates to:
  /// **'Drag and drop clip'**
  String get dragAndDropClip;

  /// No description provided for @dialogGenerateLyricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate Lyrics'**
  String get dialogGenerateLyricsTitle;

  /// No description provided for @hintDescribeSongForLyrics.
  ///
  /// In en, this message translates to:
  /// **'Describe the song (theme, story, mood)...'**
  String get hintDescribeSongForLyrics;

  /// No description provided for @dialogGeneratePromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate Prompt'**
  String get dialogGeneratePromptTitle;

  /// No description provided for @hintDescribeSongStyle.
  ///
  /// In en, this message translates to:
  /// **'Describe the song style (genre, mood, instruments)...'**
  String get hintDescribeSongStyle;

  /// No description provided for @statusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get statusProcessing;

  /// No description provided for @statusUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get statusUploading;

  /// No description provided for @statusComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get statusComplete;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @labelCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get labelCreated;

  /// No description provided for @labelParameters.
  ///
  /// In en, this message translates to:
  /// **'PARAMETERS'**
  String get labelParameters;

  /// No description provided for @labelRecreate.
  ///
  /// In en, this message translates to:
  /// **'RECREATE'**
  String get labelRecreate;

  /// No description provided for @labelKeep.
  ///
  /// In en, this message translates to:
  /// **'KEEP'**
  String get labelKeep;

  /// No description provided for @trainingSectionDataset.
  ///
  /// In en, this message translates to:
  /// **'Dataset'**
  String get trainingSectionDataset;

  /// No description provided for @labelTensorDirectory.
  ///
  /// In en, this message translates to:
  /// **'Tensor Directory'**
  String get labelTensorDirectory;

  /// No description provided for @hintTensorPath.
  ///
  /// In en, this message translates to:
  /// **'/path/to/preprocessed/tensors'**
  String get hintTensorPath;

  /// No description provided for @infoTensorDirectory.
  ///
  /// In en, this message translates to:
  /// **'Directory containing preprocessed .pt tensor files from the Dataset tab'**
  String get infoTensorDirectory;

  /// No description provided for @buttonLoadInfo.
  ///
  /// In en, this message translates to:
  /// **'Load Info'**
  String get buttonLoadInfo;

  /// No description provided for @loadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingEllipsis;

  /// No description provided for @labelDataset.
  ///
  /// In en, this message translates to:
  /// **'Dataset'**
  String get labelDataset;

  /// No description provided for @labelSamples.
  ///
  /// In en, this message translates to:
  /// **'Samples'**
  String get labelSamples;

  /// No description provided for @labelUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get labelUnknown;

  /// No description provided for @trainingSectionAdapterType.
  ///
  /// In en, this message translates to:
  /// **'Adapter Type'**
  String get trainingSectionAdapterType;

  /// No description provided for @trainingSectionLoraParams.
  ///
  /// In en, this message translates to:
  /// **'LoRA Parameters'**
  String get trainingSectionLoraParams;

  /// No description provided for @trainingSectionLokrParams.
  ///
  /// In en, this message translates to:
  /// **'LoKR Parameters'**
  String get trainingSectionLokrParams;

  /// No description provided for @trainingSectionTrainingParams.
  ///
  /// In en, this message translates to:
  /// **'Training Parameters'**
  String get trainingSectionTrainingParams;

  /// No description provided for @trainingSectionControls.
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get trainingSectionControls;

  /// No description provided for @trainingSectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get trainingSectionStatus;

  /// No description provided for @trainingSectionLoss.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get trainingSectionLoss;

  /// No description provided for @trainingSectionExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get trainingSectionExport;

  /// No description provided for @labelRank.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get labelRank;

  /// No description provided for @subtitleRank.
  ///
  /// In en, this message translates to:
  /// **'LoRA rank dimension'**
  String get subtitleRank;

  /// No description provided for @infoRank.
  ///
  /// In en, this message translates to:
  /// **'Higher rank = more capacity but more VRAM'**
  String get infoRank;

  /// No description provided for @labelAlpha.
  ///
  /// In en, this message translates to:
  /// **'Alpha'**
  String get labelAlpha;

  /// No description provided for @subtitleAlpha.
  ///
  /// In en, this message translates to:
  /// **'LoRA alpha scaling factor'**
  String get subtitleAlpha;

  /// No description provided for @infoAlpha.
  ///
  /// In en, this message translates to:
  /// **'Scales the LoRA update; typically 2x rank'**
  String get infoAlpha;

  /// No description provided for @labelDropout.
  ///
  /// In en, this message translates to:
  /// **'Dropout'**
  String get labelDropout;

  /// No description provided for @subtitleDropout.
  ///
  /// In en, this message translates to:
  /// **'LoRA dropout rate'**
  String get subtitleDropout;

  /// No description provided for @infoDropout.
  ///
  /// In en, this message translates to:
  /// **'Regularization; randomly zeroes adapter weights during training'**
  String get infoDropout;

  /// No description provided for @labelUseFp8.
  ///
  /// In en, this message translates to:
  /// **'Use FP8'**
  String get labelUseFp8;

  /// No description provided for @subtitleUseFp8.
  ///
  /// In en, this message translates to:
  /// **'Use FP8 training when runtime supports it'**
  String get subtitleUseFp8;

  /// No description provided for @infoUseFp8.
  ///
  /// In en, this message translates to:
  /// **'Reduces memory with 8-bit floating point; requires compatible GPU'**
  String get infoUseFp8;

  /// No description provided for @labelLinearDim.
  ///
  /// In en, this message translates to:
  /// **'Linear Dim'**
  String get labelLinearDim;

  /// No description provided for @subtitleLinearDim.
  ///
  /// In en, this message translates to:
  /// **'LoKR linear dimension'**
  String get subtitleLinearDim;

  /// No description provided for @infoLinearDim.
  ///
  /// In en, this message translates to:
  /// **'Kronecker decomposition dimension; similar to LoRA rank'**
  String get infoLinearDim;

  /// No description provided for @labelLinearAlpha.
  ///
  /// In en, this message translates to:
  /// **'Linear Alpha'**
  String get labelLinearAlpha;

  /// No description provided for @subtitleLinearAlpha.
  ///
  /// In en, this message translates to:
  /// **'LoKR linear alpha scaling factor'**
  String get subtitleLinearAlpha;

  /// No description provided for @infoLinearAlpha.
  ///
  /// In en, this message translates to:
  /// **'Scales the LoKR update; typically 2x linear dim'**
  String get infoLinearAlpha;

  /// No description provided for @labelFactor.
  ///
  /// In en, this message translates to:
  /// **'Factor'**
  String get labelFactor;

  /// No description provided for @hintFactorAuto.
  ///
  /// In en, this message translates to:
  /// **'-1 for auto'**
  String get hintFactorAuto;

  /// No description provided for @infoFactor.
  ///
  /// In en, this message translates to:
  /// **'Kronecker factorization factor; -1 for automatic selection'**
  String get infoFactor;

  /// No description provided for @labelDecomposeBoth.
  ///
  /// In en, this message translates to:
  /// **'Decompose Both'**
  String get labelDecomposeBoth;

  /// No description provided for @subtitleDecomposeBoth.
  ///
  /// In en, this message translates to:
  /// **'Decompose both matrices'**
  String get subtitleDecomposeBoth;

  /// No description provided for @infoDecomposeBoth.
  ///
  /// In en, this message translates to:
  /// **'Apply Kronecker decomposition to both weight matrices'**
  String get infoDecomposeBoth;

  /// No description provided for @labelUseTucker.
  ///
  /// In en, this message translates to:
  /// **'Use Tucker'**
  String get labelUseTucker;

  /// No description provided for @subtitleUseTucker.
  ///
  /// In en, this message translates to:
  /// **'Use Tucker decomposition'**
  String get subtitleUseTucker;

  /// No description provided for @infoUseTucker.
  ///
  /// In en, this message translates to:
  /// **'Use Tucker decomposition for more efficient factorization'**
  String get infoUseTucker;

  /// No description provided for @labelUseScalar.
  ///
  /// In en, this message translates to:
  /// **'Use Scalar'**
  String get labelUseScalar;

  /// No description provided for @subtitleUseScalar.
  ///
  /// In en, this message translates to:
  /// **'Use scalar calibration'**
  String get subtitleUseScalar;

  /// No description provided for @infoUseScalar.
  ///
  /// In en, this message translates to:
  /// **'Add a learnable scalar multiplier for calibration'**
  String get infoUseScalar;

  /// No description provided for @labelWeightDecompose.
  ///
  /// In en, this message translates to:
  /// **'Weight Decompose'**
  String get labelWeightDecompose;

  /// No description provided for @subtitleWeightDecompose.
  ///
  /// In en, this message translates to:
  /// **'Enable DoRA mode'**
  String get subtitleWeightDecompose;

  /// No description provided for @infoWeightDecompose.
  ///
  /// In en, this message translates to:
  /// **'Enable DoRA (Weight-Decomposed Low-Rank Adaptation)'**
  String get infoWeightDecompose;

  /// No description provided for @labelLearningRate.
  ///
  /// In en, this message translates to:
  /// **'Learning Rate'**
  String get labelLearningRate;

  /// No description provided for @infoLearningRate.
  ///
  /// In en, this message translates to:
  /// **'Step size for the optimizer; LoRA ~1e-4, LoKR ~0.03'**
  String get infoLearningRate;

  /// No description provided for @labelEpochs.
  ///
  /// In en, this message translates to:
  /// **'Epochs'**
  String get labelEpochs;

  /// No description provided for @subtitleEpochs.
  ///
  /// In en, this message translates to:
  /// **'Number of training epochs'**
  String get subtitleEpochs;

  /// No description provided for @infoEpochs.
  ///
  /// In en, this message translates to:
  /// **'Full passes over the dataset; more epochs = longer training'**
  String get infoEpochs;

  /// No description provided for @labelBatchSize.
  ///
  /// In en, this message translates to:
  /// **'Batch Size'**
  String get labelBatchSize;

  /// No description provided for @subtitleBatchSize.
  ///
  /// In en, this message translates to:
  /// **'Training batch size'**
  String get subtitleBatchSize;

  /// No description provided for @infoBatchSize.
  ///
  /// In en, this message translates to:
  /// **'Samples processed per step; higher = more VRAM'**
  String get infoBatchSize;

  /// No description provided for @labelGradientAccumulation.
  ///
  /// In en, this message translates to:
  /// **'Gradient Accumulation'**
  String get labelGradientAccumulation;

  /// No description provided for @subtitleGradientAccumulation.
  ///
  /// In en, this message translates to:
  /// **'Gradient accumulation steps'**
  String get subtitleGradientAccumulation;

  /// No description provided for @infoGradientAccumulation.
  ///
  /// In en, this message translates to:
  /// **'Simulates larger batches; effective batch = batch size x accumulation'**
  String get infoGradientAccumulation;

  /// No description provided for @labelSaveEveryNEpochs.
  ///
  /// In en, this message translates to:
  /// **'Save Every N Epochs'**
  String get labelSaveEveryNEpochs;

  /// No description provided for @subtitleSaveEveryNEpochs.
  ///
  /// In en, this message translates to:
  /// **'Checkpoint save interval'**
  String get subtitleSaveEveryNEpochs;

  /// No description provided for @infoSaveEveryNEpochs.
  ///
  /// In en, this message translates to:
  /// **'Save a checkpoint every N epochs'**
  String get infoSaveEveryNEpochs;

  /// No description provided for @subtitleTrainingShift.
  ///
  /// In en, this message translates to:
  /// **'Training timestep shift'**
  String get subtitleTrainingShift;

  /// No description provided for @infoTrainingShift.
  ///
  /// In en, this message translates to:
  /// **'Fixed at 3.0 for turbo model'**
  String get infoTrainingShift;

  /// No description provided for @infoSeed.
  ///
  /// In en, this message translates to:
  /// **'Random seed for reproducibility'**
  String get infoSeed;

  /// No description provided for @labelGradientCheckpointing.
  ///
  /// In en, this message translates to:
  /// **'Gradient Checkpointing'**
  String get labelGradientCheckpointing;

  /// No description provided for @subtitleGradientCheckpointing.
  ///
  /// In en, this message translates to:
  /// **'Trade compute speed for lower VRAM usage'**
  String get subtitleGradientCheckpointing;

  /// No description provided for @infoGradientCheckpointing.
  ///
  /// In en, this message translates to:
  /// **'Recomputes activations to save VRAM; slower but uses less memory'**
  String get infoGradientCheckpointing;

  /// No description provided for @labelOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Output Directory'**
  String get labelOutputDirectory;

  /// No description provided for @infoOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Directory to save adapter checkpoints during training'**
  String get infoOutputDirectory;

  /// No description provided for @buttonStartTraining.
  ///
  /// In en, this message translates to:
  /// **'Start Training'**
  String get buttonStartTraining;

  /// No description provided for @buttonStopTraining.
  ///
  /// In en, this message translates to:
  /// **'Stop Training'**
  String get buttonStopTraining;

  /// No description provided for @trainingLabelStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get trainingLabelStatus;

  /// No description provided for @trainingLabelEpoch.
  ///
  /// In en, this message translates to:
  /// **'Epoch'**
  String get trainingLabelEpoch;

  /// No description provided for @trainingLabelStep.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get trainingLabelStep;

  /// No description provided for @trainingLabelLoss.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get trainingLabelLoss;

  /// No description provided for @trainingLabelSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get trainingLabelSpeed;

  /// No description provided for @trainingSpeedValue.
  ///
  /// In en, this message translates to:
  /// **'{value} steps/s'**
  String trainingSpeedValue(String value);

  /// No description provided for @trainingLabelETA.
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get trainingLabelETA;

  /// No description provided for @trainingErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String trainingErrorPrefix(String error);

  /// No description provided for @trainingTensorboard.
  ///
  /// In en, this message translates to:
  /// **'TensorBoard: {url}'**
  String trainingTensorboard(String url);

  /// No description provided for @trainingStopRequested.
  ///
  /// In en, this message translates to:
  /// **'Stop requested'**
  String get trainingStopRequested;

  /// No description provided for @trainingComplete.
  ///
  /// In en, this message translates to:
  /// **'Training complete'**
  String get trainingComplete;

  /// No description provided for @errorInvalidLearningRate.
  ///
  /// In en, this message translates to:
  /// **'Invalid learning rate'**
  String get errorInvalidLearningRate;

  /// No description provided for @errorExportPathRequired.
  ///
  /// In en, this message translates to:
  /// **'Export path is required'**
  String get errorExportPathRequired;

  /// No description provided for @labelExportPath.
  ///
  /// In en, this message translates to:
  /// **'Export Path'**
  String get labelExportPath;

  /// No description provided for @hintExportPath.
  ///
  /// In en, this message translates to:
  /// **'/path/to/export/lora'**
  String get hintExportPath;

  /// No description provided for @infoExportPath.
  ///
  /// In en, this message translates to:
  /// **'Destination path for the final exported adapter'**
  String get infoExportPath;

  /// No description provided for @buttonExportLora.
  ///
  /// In en, this message translates to:
  /// **'Export LoRA'**
  String get buttonExportLora;

  /// No description provided for @exportingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get exportingEllipsis;

  /// No description provided for @loraExportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'LoRA exported successfully'**
  String get loraExportedSuccessfully;

  /// No description provided for @datasetSectionUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload Dataset Zip'**
  String get datasetSectionUpload;

  /// No description provided for @buttonChooseZip.
  ///
  /// In en, this message translates to:
  /// **'Choose .zip'**
  String get buttonChooseZip;

  /// No description provided for @labelDatasetName.
  ///
  /// In en, this message translates to:
  /// **'Dataset Name'**
  String get labelDatasetName;

  /// No description provided for @infoDatasetName.
  ///
  /// In en, this message translates to:
  /// **'Name identifier for the dataset'**
  String get infoDatasetName;

  /// No description provided for @labelCustomTag.
  ///
  /// In en, this message translates to:
  /// **'Custom Tag'**
  String get labelCustomTag;

  /// No description provided for @hintCustomTag.
  ///
  /// In en, this message translates to:
  /// **'Optional tag for captions'**
  String get hintCustomTag;

  /// No description provided for @infoCustomTag.
  ///
  /// In en, this message translates to:
  /// **'Activation tag added to captions during training'**
  String get infoCustomTag;

  /// No description provided for @labelTagPosition.
  ///
  /// In en, this message translates to:
  /// **'Tag Position'**
  String get labelTagPosition;

  /// No description provided for @infoTagPosition.
  ///
  /// In en, this message translates to:
  /// **'Where to insert the custom tag relative to captions'**
  String get infoTagPosition;

  /// No description provided for @labelAllInstrumental.
  ///
  /// In en, this message translates to:
  /// **'All Instrumental'**
  String get labelAllInstrumental;

  /// No description provided for @subtitleAllInstrumental.
  ///
  /// In en, this message translates to:
  /// **'Mark all samples as instrumental'**
  String get subtitleAllInstrumental;

  /// No description provided for @infoAllInstrumental.
  ///
  /// In en, this message translates to:
  /// **'Treat all samples as having no vocals'**
  String get infoAllInstrumental;

  /// No description provided for @uploadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploadingEllipsis;

  /// No description provided for @uploadedSamples.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {count} samples'**
  String uploadedSamples(int count);

  /// No description provided for @datasetSectionLoad.
  ///
  /// In en, this message translates to:
  /// **'Load Existing Dataset'**
  String get datasetSectionLoad;

  /// No description provided for @labelDatasetJsonPath.
  ///
  /// In en, this message translates to:
  /// **'Dataset JSON Path'**
  String get labelDatasetJsonPath;

  /// No description provided for @infoDatasetJsonPath.
  ///
  /// In en, this message translates to:
  /// **'Path to a previously saved dataset.json on the server'**
  String get infoDatasetJsonPath;

  /// No description provided for @buttonLoad.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get buttonLoad;

  /// No description provided for @loadedSamples.
  ///
  /// In en, this message translates to:
  /// **'Loaded {count} samples'**
  String loadedSamples(int count);

  /// No description provided for @datasetSectionAutoLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto-Label'**
  String get datasetSectionAutoLabel;

  /// No description provided for @labelSkipMetas.
  ///
  /// In en, this message translates to:
  /// **'Skip Metas'**
  String get labelSkipMetas;

  /// No description provided for @subtitleSkipMetas.
  ///
  /// In en, this message translates to:
  /// **'Skip BPM/Key/TimeSig detection'**
  String get subtitleSkipMetas;

  /// No description provided for @infoSkipMetas.
  ///
  /// In en, this message translates to:
  /// **'Skip BPM, key, and time signature detection to speed up labeling'**
  String get infoSkipMetas;

  /// No description provided for @labelFormatLyrics.
  ///
  /// In en, this message translates to:
  /// **'Format Lyrics'**
  String get labelFormatLyrics;

  /// No description provided for @subtitleFormatLyrics.
  ///
  /// In en, this message translates to:
  /// **'Format lyrics via LLM'**
  String get subtitleFormatLyrics;

  /// No description provided for @infoFormatLyrics.
  ///
  /// In en, this message translates to:
  /// **'Reformat user-provided lyrics using the LLM'**
  String get infoFormatLyrics;

  /// No description provided for @labelTranscribeLyrics.
  ///
  /// In en, this message translates to:
  /// **'Transcribe Lyrics'**
  String get labelTranscribeLyrics;

  /// No description provided for @subtitleTranscribeLyrics.
  ///
  /// In en, this message translates to:
  /// **'Transcribe from audio'**
  String get subtitleTranscribeLyrics;

  /// No description provided for @infoTranscribeLyrics.
  ///
  /// In en, this message translates to:
  /// **'Transcribe lyrics from audio using speech recognition'**
  String get infoTranscribeLyrics;

  /// No description provided for @labelOnlyUnlabeled.
  ///
  /// In en, this message translates to:
  /// **'Only Unlabeled'**
  String get labelOnlyUnlabeled;

  /// No description provided for @subtitleOnlyUnlabeled.
  ///
  /// In en, this message translates to:
  /// **'Only label unlabeled samples'**
  String get subtitleOnlyUnlabeled;

  /// No description provided for @infoOnlyUnlabeled.
  ///
  /// In en, this message translates to:
  /// **'Skip samples that already have labels'**
  String get infoOnlyUnlabeled;

  /// No description provided for @labelSavePathOptional.
  ///
  /// In en, this message translates to:
  /// **'Save Path (optional)'**
  String get labelSavePathOptional;

  /// No description provided for @infoAutoLabelSavePath.
  ///
  /// In en, this message translates to:
  /// **'Auto-save labeling progress to this JSON file'**
  String get infoAutoLabelSavePath;

  /// No description provided for @labelChunkSize.
  ///
  /// In en, this message translates to:
  /// **'Chunk Size'**
  String get labelChunkSize;

  /// No description provided for @infoChunkSize.
  ///
  /// In en, this message translates to:
  /// **'Number of audio samples to encode per VAE batch'**
  String get infoChunkSize;

  /// No description provided for @labelBatchSizeDataset.
  ///
  /// In en, this message translates to:
  /// **'Batch Size'**
  String get labelBatchSizeDataset;

  /// No description provided for @infoBatchSizeDataset.
  ///
  /// In en, this message translates to:
  /// **'Samples processed per labeling batch'**
  String get infoBatchSizeDataset;

  /// No description provided for @labelingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Labeling...'**
  String get labelingEllipsis;

  /// No description provided for @buttonStartAutoLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Auto-Label'**
  String get buttonStartAutoLabel;

  /// No description provided for @startingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get startingEllipsis;

  /// No description provided for @processingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processingEllipsis;

  /// No description provided for @autoLabelingComplete.
  ///
  /// In en, this message translates to:
  /// **'Auto-labeling complete'**
  String get autoLabelingComplete;

  /// No description provided for @autoLabelingFailed.
  ///
  /// In en, this message translates to:
  /// **'Auto-labeling failed'**
  String get autoLabelingFailed;

  /// No description provided for @datasetSectionSamples.
  ///
  /// In en, this message translates to:
  /// **'Samples ({count})'**
  String datasetSectionSamples(int count);

  /// No description provided for @datasetSectionSave.
  ///
  /// In en, this message translates to:
  /// **'Save Dataset'**
  String get datasetSectionSave;

  /// No description provided for @labelSavePath.
  ///
  /// In en, this message translates to:
  /// **'Save Path'**
  String get labelSavePath;

  /// No description provided for @infoSavePath.
  ///
  /// In en, this message translates to:
  /// **'Path to save the dataset JSON file on the server'**
  String get infoSavePath;

  /// No description provided for @savingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get savingEllipsis;

  /// No description provided for @datasetSaved.
  ///
  /// In en, this message translates to:
  /// **'Dataset saved'**
  String get datasetSaved;

  /// No description provided for @datasetSectionPreprocess.
  ///
  /// In en, this message translates to:
  /// **'Preprocess'**
  String get datasetSectionPreprocess;

  /// No description provided for @infoOutputDirectoryPreprocess.
  ///
  /// In en, this message translates to:
  /// **'Directory for preprocessed tensor files used in training'**
  String get infoOutputDirectoryPreprocess;

  /// No description provided for @labelSkipExisting.
  ///
  /// In en, this message translates to:
  /// **'Skip Existing'**
  String get labelSkipExisting;

  /// No description provided for @subtitleSkipExisting.
  ///
  /// In en, this message translates to:
  /// **'Skip samples already preprocessed'**
  String get subtitleSkipExisting;

  /// No description provided for @infoSkipExisting.
  ///
  /// In en, this message translates to:
  /// **'Skip samples that already have preprocessed tensors'**
  String get infoSkipExisting;

  /// No description provided for @preprocessingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get preprocessingEllipsis;

  /// No description provided for @buttonPreprocess.
  ///
  /// In en, this message translates to:
  /// **'Preprocess'**
  String get buttonPreprocess;

  /// No description provided for @preprocessingComplete.
  ///
  /// In en, this message translates to:
  /// **'Preprocessing complete'**
  String get preprocessingComplete;

  /// No description provided for @preprocessingFailed.
  ///
  /// In en, this message translates to:
  /// **'Preprocessing failed'**
  String get preprocessingFailed;

  /// No description provided for @sampleLabelCaption.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get sampleLabelCaption;

  /// No description provided for @infoCaption.
  ///
  /// In en, this message translates to:
  /// **'Text description of the music style and mood'**
  String get infoCaption;

  /// No description provided for @sampleLabelGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get sampleLabelGenre;

  /// No description provided for @infoGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre tags (e.g. rock, electronic, ambient)'**
  String get infoGenre;

  /// No description provided for @sampleLabelLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get sampleLabelLyrics;

  /// No description provided for @infoLyrics.
  ///
  /// In en, this message translates to:
  /// **'Song lyrics or [Instrumental] for instrumental tracks'**
  String get infoLyrics;

  /// No description provided for @sampleLabelBpm.
  ///
  /// In en, this message translates to:
  /// **'BPM'**
  String get sampleLabelBpm;

  /// No description provided for @infoBpm.
  ///
  /// In en, this message translates to:
  /// **'Beats per minute'**
  String get infoBpm;

  /// No description provided for @sampleLabelKey.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get sampleLabelKey;

  /// No description provided for @infoKey.
  ///
  /// In en, this message translates to:
  /// **'Musical key (e.g. C Major)'**
  String get infoKey;

  /// No description provided for @sampleLabelTimeSig.
  ///
  /// In en, this message translates to:
  /// **'Time Sig'**
  String get sampleLabelTimeSig;

  /// No description provided for @infoTimeSig.
  ///
  /// In en, this message translates to:
  /// **'Time signature (e.g. 4/4)'**
  String get infoTimeSig;

  /// No description provided for @sampleLabelLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sampleLabelLanguage;

  /// No description provided for @infoLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language of the vocals (or unknown)'**
  String get infoLanguage;

  /// No description provided for @sampleLabelInstrumental.
  ///
  /// In en, this message translates to:
  /// **'Instrumental'**
  String get sampleLabelInstrumental;

  /// No description provided for @infoInstrumental.
  ///
  /// In en, this message translates to:
  /// **'Whether this sample has no vocals'**
  String get infoInstrumental;

  /// No description provided for @updatingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Updating...'**
  String get updatingEllipsis;

  /// No description provided for @buttonUpdateSample.
  ///
  /// In en, this message translates to:
  /// **'Update Sample'**
  String get buttonUpdateSample;

  /// No description provided for @sampleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Sample updated'**
  String get sampleUpdated;

  /// No description provided for @taskTypeGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate a short music clip from a text prompt'**
  String get taskTypeGenerate;

  /// No description provided for @taskTypeGenerateLong.
  ///
  /// In en, this message translates to:
  /// **'Generate a longer music track from a text prompt'**
  String get taskTypeGenerateLong;

  /// No description provided for @taskTypeUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload an existing audio file'**
  String get taskTypeUpload;

  /// No description provided for @taskTypeInfill.
  ///
  /// In en, this message translates to:
  /// **'Fill in a section of audio between two points'**
  String get taskTypeInfill;

  /// No description provided for @taskTypeCover.
  ///
  /// In en, this message translates to:
  /// **'Create a cover version in a different style'**
  String get taskTypeCover;

  /// No description provided for @taskTypeExtract.
  ///
  /// In en, this message translates to:
  /// **'Separate audio into individual stems (vocals, drums, etc.)'**
  String get taskTypeExtract;

  /// No description provided for @taskTypeAddStem.
  ///
  /// In en, this message translates to:
  /// **'Add a new instrument or vocal layer to existing audio'**
  String get taskTypeAddStem;

  /// No description provided for @taskTypeExtend.
  ///
  /// In en, this message translates to:
  /// **'Extend an existing audio clip with new content'**
  String get taskTypeExtend;

  /// No description provided for @navLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get navLyrics;

  /// No description provided for @labelLyricBook.
  ///
  /// In en, this message translates to:
  /// **'Lyric Book'**
  String get labelLyricBook;

  /// No description provided for @tooltipOpenLyricBook.
  ///
  /// In en, this message translates to:
  /// **'Open lyric book'**
  String get tooltipOpenLyricBook;

  /// No description provided for @lyricBookSearch.
  ///
  /// In en, this message translates to:
  /// **'Search lyrics...'**
  String get lyricBookSearch;

  /// No description provided for @lyricBookNewSheet.
  ///
  /// In en, this message translates to:
  /// **'New Lyric Sheet'**
  String get lyricBookNewSheet;

  /// No description provided for @lyricBookNoSheets.
  ///
  /// In en, this message translates to:
  /// **'No lyric sheets yet'**
  String get lyricBookNoSheets;

  /// No description provided for @lyricBookLinkedSongs.
  ///
  /// In en, this message translates to:
  /// **'Linked Songs'**
  String get lyricBookLinkedSongs;

  /// No description provided for @lyricBookNoLinkedSongs.
  ///
  /// In en, this message translates to:
  /// **'No songs linked'**
  String get lyricBookNoLinkedSongs;

  /// No description provided for @lyricBookDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Lyric Sheet'**
  String get lyricBookDeleteTitle;

  /// No description provided for @lyricBookDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this lyric sheet? Your songs will not be deleted.'**
  String get lyricBookDeleteContent;

  /// No description provided for @lyricBookUseForGeneration.
  ///
  /// In en, this message translates to:
  /// **'Use for generation'**
  String get lyricBookUseForGeneration;

  /// No description provided for @lyricBookSaveToBook.
  ///
  /// In en, this message translates to:
  /// **'Save to Lyric Book'**
  String get lyricBookSaveToBook;

  /// No description provided for @lyricBookSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to lyric book'**
  String get lyricBookSaved;

  /// No description provided for @lyricBookSearchSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs with matching lyrics'**
  String get lyricBookSearchSongs;

  /// No description provided for @lyricBookReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace Lyrics'**
  String get lyricBookReplaceTitle;

  /// No description provided for @lyricBookReplaceContent.
  ///
  /// In en, this message translates to:
  /// **'This will replace your current lyrics. Continue?'**
  String get lyricBookReplaceContent;

  /// No description provided for @buttonReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get buttonReplace;

  /// No description provided for @systemHeading.
  ///
  /// In en, this message translates to:
  /// **'System Information'**
  String get systemHeading;

  /// No description provided for @systemInfoDescription.
  ///
  /// In en, this message translates to:
  /// **'Hardware and browser details for troubleshooting.'**
  String get systemInfoDescription;

  /// No description provided for @systemBrowser.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get systemBrowser;

  /// No description provided for @systemBrowserVersion.
  ///
  /// In en, this message translates to:
  /// **'Browser Version'**
  String get systemBrowserVersion;

  /// No description provided for @systemOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'Operating System'**
  String get systemOperatingSystem;

  /// No description provided for @systemGraphicsCard.
  ///
  /// In en, this message translates to:
  /// **'Graphics Card'**
  String get systemGraphicsCard;

  /// No description provided for @systemGraphicsDriver.
  ///
  /// In en, this message translates to:
  /// **'Graphics Driver'**
  String get systemGraphicsDriver;

  /// No description provided for @systemMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get systemMemory;

  /// No description provided for @systemCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get systemCpu;

  /// No description provided for @systemCpuCores.
  ///
  /// In en, this message translates to:
  /// **'CPU Cores'**
  String get systemCpuCores;

  /// No description provided for @systemGpuMemory.
  ///
  /// In en, this message translates to:
  /// **'GPU Memory'**
  String get systemGpuMemory;

  /// No description provided for @systemCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy All'**
  String get systemCopyAll;

  /// No description provided for @systemCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get systemCopied;

  /// No description provided for @systemBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get systemBranch;

  /// No description provided for @systemUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get systemUnavailable;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
