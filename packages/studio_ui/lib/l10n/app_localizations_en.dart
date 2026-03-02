// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Studio';

  @override
  String get remoteLabel => 'REMOTE';

  @override
  String get navCreate => 'Create';

  @override
  String get navTraining => 'Training';

  @override
  String get navSettings => 'Settings';

  @override
  String get buttonCancel => 'Cancel';

  @override
  String get buttonDelete => 'Delete';

  @override
  String get buttonSave => 'Save';

  @override
  String get buttonSelect => 'Select';

  @override
  String get buttonGenerate => 'Create';

  @override
  String get buttonUpload => 'Upload';

  @override
  String get buttonEdit => 'Edit';

  @override
  String get buttonClear => 'Clear';

  @override
  String get buttonActivate => 'Activate';

  @override
  String get buttonReset => 'Reset';

  @override
  String get buttonUpdate => 'Update';

  @override
  String get tooltipPrevious => 'Previous';

  @override
  String get tooltipPlay => 'Play';

  @override
  String get tooltipPause => 'Pause';

  @override
  String get tooltipNext => 'Next';

  @override
  String get tooltipLoop => 'Loop';

  @override
  String get tooltipShowQueue => 'Show Queue';

  @override
  String get tooltipQueue => 'Queue';

  @override
  String get tooltipNew => 'New';

  @override
  String get tooltipSortOrder => 'Sort order';

  @override
  String get tooltipFilter => 'Filter';

  @override
  String get tooltipLike => 'Like';

  @override
  String get tooltipDislike => 'Dislike';

  @override
  String get tooltipDownload => 'Download';

  @override
  String get tooltipDelete => 'Delete';

  @override
  String get tooltipRefresh => 'Refresh';

  @override
  String get tooltipRemove => 'Remove';

  @override
  String get tooltipCopied => 'Copied!';

  @override
  String get tooltipCopyToClipboard => 'Copy to clipboard';

  @override
  String get tooltipBrowse => 'Browse...';

  @override
  String get tooltipNowPlaying => 'Now playing';

  @override
  String tooltipGenerateWithAi(String text) {
    return 'Generate $text with AI';
  }

  @override
  String tooltipSourceClipRequired(String taskType) {
    return 'A source clip is required for $taskType';
  }

  @override
  String get queueTitle => 'Queue';

  @override
  String get queueEmpty => 'Your queue is empty';

  @override
  String get dialogSelectFile => 'Select File';

  @override
  String get dialogSelectDirectory => 'Select Directory';

  @override
  String get noMatchingFiles => 'No matching files';

  @override
  String get noSubdirectories => 'No subdirectories';

  @override
  String get settingsHeading => 'Settings';

  @override
  String get tabServer => 'Server';

  @override
  String get tabLogs => 'Logs';

  @override
  String get tabPeers => 'Peers';

  @override
  String get tabPrompts => 'Prompts';

  @override
  String get tabDisplay => 'Visualizers';

  @override
  String get tabAbout => 'About';

  @override
  String get tabSystem => 'System';

  @override
  String get trainingHeading => 'Training';

  @override
  String get tabDataset => 'Dataset';

  @override
  String get tabTraining => 'Training';

  @override
  String get serverAllowConnections => 'Allow Connections';

  @override
  String get serverAllowConnectionsDescription =>
      'When enabled, peers can connect to this server';

  @override
  String get serverEnvironment => 'Environment';

  @override
  String get serverBackends => 'Server Backends';

  @override
  String get serverLabelBuild => 'Build';

  @override
  String get serverLabelApiHost => 'API Host';

  @override
  String get serverLabelSecure => 'Secure';

  @override
  String get serverLabelHost => 'Host';

  @override
  String get serverLabelProtocol => 'Protocol';

  @override
  String get serverLabelStatus => 'Status';

  @override
  String get serverStatusActive => 'Active';

  @override
  String get serverStatusInactive => 'Inactive';

  @override
  String get serverNoBackends => 'No server backends configured.';

  @override
  String serverActiveLabel(String name) {
    return '$name (active)';
  }

  @override
  String get buttonAddServer => 'Add Server';

  @override
  String get dialogEditServer => 'Edit Server';

  @override
  String get dialogAddServer => 'Add Server';

  @override
  String get labelName => 'Name';

  @override
  String get labelApiHost => 'API Host';

  @override
  String get hintLocalhost => 'localhost:8080';

  @override
  String get labelHttps => 'HTTPS';

  @override
  String get buttonTestConnection => 'Test Connection';

  @override
  String get testingConnection => 'Testing...';

  @override
  String get healthHealthy => 'Healthy';

  @override
  String get healthUnreachable => 'Unreachable';

  @override
  String get logsHeading => 'Server Logs';

  @override
  String get infoLogs => 'Recent log output from the server process';

  @override
  String get logsEmpty => 'No log entries.';

  @override
  String get peersHeading => 'Peer Connections';

  @override
  String get infoPeers =>
      'Peers are other Studio instances that have connected to this server. You can block a peer to reject its requests.';

  @override
  String get peersEmpty => 'No peer connections yet.';

  @override
  String get peerBlocked => 'BLOCKED';

  @override
  String get buttonBlock => 'Block';

  @override
  String get buttonUnblock => 'Unblock';

  @override
  String get peerFirstSeen => 'First seen';

  @override
  String get peerLastSeen => 'Last seen';

  @override
  String get peerRequests => 'Requests';

  @override
  String get promptsHeading => 'AI System Prompts';

  @override
  String get infoPrompts =>
      'Custom system prompts sent to the LLM when generating lyrics or audio descriptions. Leave blank to use defaults.';

  @override
  String get promptsAudioModel => 'Audio model';

  @override
  String get promptsLyricsGeneration => 'Lyrics generation';

  @override
  String get promptsAudioPromptGeneration => 'Audio prompt generation';

  @override
  String get promptsSettingsSaved => 'Settings saved.';

  @override
  String get displayVisualizerHeading => 'Visualizer';

  @override
  String get displayVisualizerDescription =>
      'Choose the visualizer style for cover art.';

  @override
  String get visualizerCreamdrop => 'Creamdrop';

  @override
  String get visualizerCreamdropDescription =>
      'Swirling fractal plasma with domain-warped noise.';

  @override
  String get visualizerWaveform => 'Waveform';

  @override
  String get visualizerWaveformDescription =>
      'Concentric rings and petals pulsing with audio.';

  @override
  String get visualizerSpectrum => 'Spectrum';

  @override
  String get visualizerSpectrumDescription =>
      'Explosive color fields driven by frequency bands.';

  @override
  String get displaySettingsSaved => 'Settings saved.';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutCredits => 'Credits';

  @override
  String get aboutStudioBy => 's t u d i o by ';

  @override
  String get aboutDiskrot => 'diskrot';

  @override
  String get aboutSourceOnGithub => 'source on GitHub';

  @override
  String get aboutServerPublicKey => 'Server Public Key';

  @override
  String get aboutBranch => 'Branch';

  @override
  String get createHeading => 'Create';

  @override
  String get labelModel => 'Model';

  @override
  String get modelAceStep => 'ACE Step 1.5';

  @override
  String get modelBark => 'Bark';

  @override
  String get labelTaskType => 'Task Type';

  @override
  String get labelTitle => 'Title';

  @override
  String get hintSongTitle => 'Song title...';

  @override
  String get labelLyrics => 'Lyrics';

  @override
  String get hintEnterLyrics => 'Enter lyrics...';

  @override
  String get labelPrompt => 'Prompt';

  @override
  String get labelGenres => 'Genres';

  @override
  String get hintSearchGenres => 'Type to search genres...';

  @override
  String get hintDescribeStyle => 'Describe the style, mood, genre...';

  @override
  String get labelAvoid => 'Avoid';

  @override
  String get hintDescribeAvoid => 'Describe what to avoid...';

  @override
  String get noTasksYet => 'No songs found';

  @override
  String get backToTasks => 'Back to tasks';

  @override
  String get tooltipMoveWorkspace => 'Move to workspace';

  @override
  String movedToWorkspace(String name) {
    return 'Moved to $name';
  }

  @override
  String get dialogMoveToWorkspaceTitle => 'Move to Workspace';

  @override
  String get filterAll => 'All';

  @override
  String get filterLiked => 'Liked';

  @override
  String get filterDisliked => 'Disliked';

  @override
  String get sortNewestFirst => 'Newest first';

  @override
  String get sortOldestFirst => 'Oldest first';

  @override
  String get buttonUnselect => 'Unselect';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String buttonMoveCount(int count) {
    return 'Move ($count)';
  }

  @override
  String buttonDeleteCount(int count) {
    return 'Delete ($count)';
  }

  @override
  String get dialogDeleteSongsTitle => 'Delete Songs';

  @override
  String dialogDeleteSongsContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'songs',
      one: 'song',
    );
    return 'Delete $count selected $_temp0? This action cannot be undone.';
  }

  @override
  String get dialogDeleteSongTitle => 'Delete Song';

  @override
  String get dialogDeleteSongContent => 'This action cannot be undone.';

  @override
  String get detailsHeading => 'Details';

  @override
  String get noLyrics => 'No lyrics';

  @override
  String get snackbarLyricsCopied => 'Lyrics copied';

  @override
  String get snackbarDownloadComplete => 'Download complete';

  @override
  String snackbarFailedGenerateLyrics(String error) {
    return 'Failed to generate lyrics: $error';
  }

  @override
  String snackbarFailedGeneratePrompt(String error) {
    return 'Failed to generate prompt: $error';
  }

  @override
  String get errorSelectAudioFile => 'Please select an audio file first';

  @override
  String labelCopied(String label) {
    return '$label copied';
  }

  @override
  String get labelCreativity => 'Creativity';

  @override
  String get subtitleCreativity => 'Predictable to surprising';

  @override
  String get infoCreativity =>
      'Controls how unpredictable the output is. Low values produce safer, more conventional results. High values make the AI take bigger creative risks.';

  @override
  String get labelPromptStrength => 'Prompt Strength';

  @override
  String get subtitlePromptStrength =>
      'How closely it follows your description';

  @override
  String get infoPromptStrength =>
      'How literally the AI follows your text prompt. Higher values stick closely to what you described. Lower values give the AI more freedom to interpret.';

  @override
  String get labelQuality => 'Quality';

  @override
  String get subtitleQuality => 'Higher = better but slower';

  @override
  String get infoQuality =>
      'Number of processing steps. More steps generally produce cleaner, higher-fidelity audio but take longer to generate.';

  @override
  String get labelDuration => 'Duration';

  @override
  String get subtitleDuration => 'Length of generated audio';

  @override
  String get infoDuration =>
      'How long the generated audio clip will be, in seconds.';

  @override
  String get labelVariations => 'Variations';

  @override
  String get subtitleVariations => 'Number of versions to create';

  @override
  String get infoVariations =>
      'Generates multiple different versions from the same prompt so you can pick your favorite.';

  @override
  String get labelCfgScale => 'CFG Scale';

  @override
  String get subtitleCfgScale => 'Classifier-free guidance strength';

  @override
  String get infoCfgScale =>
      'Balances prompt-following vs. audio quality. Too low ignores your prompt; too high can distort the sound.';

  @override
  String get labelTopP => 'Top P';

  @override
  String get subtitleTopP => 'Nucleus sampling threshold';

  @override
  String get infoTopP =>
      'Limits the AI to only the most likely choices at each step. Lower values are more focused and predictable; higher values allow more variety.';

  @override
  String get labelRepetitionPenalty => 'Repetition Penalty';

  @override
  String get subtitleRepetitionPenalty => 'Penalize repeated patterns';

  @override
  String get infoRepetitionPenalty =>
      'Discourages the AI from repeating the same musical phrases. Higher values push for more variation throughout the track.';

  @override
  String get labelShift => 'Shift';

  @override
  String get subtitleShift => 'Audio shift amount';

  @override
  String get infoShift =>
      'Adjusts the noise schedule during generation. Higher values can change the tonal character and texture of the output.';

  @override
  String get labelCfgIntervalStart => 'CFG Interval Start';

  @override
  String get subtitleCfgIntervalStart => 'When guidance begins';

  @override
  String get infoCfgIntervalStart =>
      'The point in generation when prompt guidance kicks in. 0 means from the very start; higher values let early steps run freely.';

  @override
  String get labelCfgIntervalEnd => 'CFG Interval End';

  @override
  String get subtitleCfgIntervalEnd => 'When guidance stops';

  @override
  String get infoCfgIntervalEnd =>
      'The point in generation when prompt guidance turns off. 1 means guidance runs until the end; lower values let final steps refine freely.';

  @override
  String get labelThinking => 'Thinking';

  @override
  String get subtitleThinking => 'Enable extended thinking';

  @override
  String get infoThinking =>
      'Lets the AI reason about your prompt before generating. Can improve results for complex descriptions but adds processing time.';

  @override
  String get labelConstrainedDecoding => 'Constrained Decoding';

  @override
  String get subtitleConstrainedDecoding => 'Enable constrained decoding';

  @override
  String get infoConstrainedDecoding =>
      'Forces the AI to follow stricter musical rules during generation. Produces more structured output but may limit creative surprises.';

  @override
  String get labelRandomSeed => 'Random Seed';

  @override
  String get subtitleRandomSeed => 'Use a random seed each run';

  @override
  String get infoRandomSeed =>
      'When on, every generation is unique. When off, the same settings and prompt will produce the same result each time.';

  @override
  String get labelSeed => 'Seed';

  @override
  String get hintEnterNumber => 'Enter a number...';

  @override
  String get labelAdvanced => 'Advanced';

  @override
  String get labelLoraScale => 'LoRA Scale';

  @override
  String get subtitleLoraScale => 'Adapter strength';

  @override
  String get labelLora => 'LoRA';

  @override
  String get labelActiveAdapter => 'Active Adapter';

  @override
  String get buttonUnloadAll => 'Unload All';

  @override
  String get labelLoadNew => 'Load New';

  @override
  String get labelAvailableLoras => 'Available LoRAs';

  @override
  String get buttonLoadLora => 'Load LoRA';

  @override
  String get labelSetParameters => 'Set Parameters';

  @override
  String get labelAudioFile => 'Audio File';

  @override
  String get clickToSelectAudioFile => 'Click to select an audio file';

  @override
  String get labelSourceClip => 'Source Clip';

  @override
  String get labelStart => 'Start';

  @override
  String get labelEnd => 'End';

  @override
  String get hintDescribeStem => 'Describe the stem to generate...';

  @override
  String get hintDescribeExtendStyle =>
      'Describe the music style to extend with...';

  @override
  String get hintExtendLyrics =>
      '[Instrumental] or write lyrics for the extension...';

  @override
  String get hintTrackClasses => 'vocals, drums, bass';

  @override
  String get labelRepaintStart => 'Repaint Start';

  @override
  String get labelRepaintEnd => 'Repaint End';

  @override
  String get labelCropStart => 'Crop Start';

  @override
  String get labelCropEnd => 'Crop End';

  @override
  String get labelFadeIn => 'Fade In (seconds)';

  @override
  String get labelFadeOut => 'Fade Out (seconds)';

  @override
  String get labelStem => 'Stem';

  @override
  String get labelTrackClasses => 'Track Classes';

  @override
  String get dropToSetSourceClip => 'Drop to set source clip';

  @override
  String get dragAndDropClip => 'Drag and drop clip';

  @override
  String get dialogGenerateLyricsTitle => 'Generate Lyrics';

  @override
  String get hintDescribeSongForLyrics =>
      'Describe the song (theme, story, mood)...';

  @override
  String get dialogGeneratePromptTitle => 'Generate Prompt';

  @override
  String get hintDescribeSongStyle =>
      'Describe the song style (genre, mood, instruments)...';

  @override
  String get statusProcessing => 'Processing';

  @override
  String get statusUploading => 'Uploading';

  @override
  String get statusComplete => 'Complete';

  @override
  String get statusFailed => 'Failed';

  @override
  String get justNow => 'Just now';

  @override
  String get labelCreated => 'Created';

  @override
  String get labelParameters => 'PARAMETERS';

  @override
  String get labelRecreate => 'RECREATE';

  @override
  String get labelKeep => 'KEEP';

  @override
  String get trainingSectionDataset => 'Dataset';

  @override
  String get labelTensorDirectory => 'Tensor Directory';

  @override
  String get hintTensorPath => '/path/to/preprocessed/tensors';

  @override
  String get infoTensorDirectory =>
      'Directory containing preprocessed .pt tensor files from the Dataset tab';

  @override
  String get buttonLoadInfo => 'Load Info';

  @override
  String get loadingEllipsis => 'Loading...';

  @override
  String get labelDataset => 'Dataset';

  @override
  String get labelSamples => 'Samples';

  @override
  String get labelUnknown => 'Unknown';

  @override
  String get trainingSectionAdapterType => 'Adapter Type';

  @override
  String get trainingSectionLoraParams => 'LoRA Parameters';

  @override
  String get trainingSectionLokrParams => 'LoKR Parameters';

  @override
  String get trainingSectionTrainingParams => 'Training Parameters';

  @override
  String get trainingSectionControls => 'Controls';

  @override
  String get trainingSectionStatus => 'Status';

  @override
  String get trainingSectionLoss => 'Loss';

  @override
  String get trainingSectionExport => 'Export';

  @override
  String get labelRank => 'Rank';

  @override
  String get subtitleRank => 'LoRA rank dimension';

  @override
  String get infoRank => 'Higher rank = more capacity but more VRAM';

  @override
  String get labelAlpha => 'Alpha';

  @override
  String get subtitleAlpha => 'LoRA alpha scaling factor';

  @override
  String get infoAlpha => 'Scales the LoRA update; typically 2x rank';

  @override
  String get labelDropout => 'Dropout';

  @override
  String get subtitleDropout => 'LoRA dropout rate';

  @override
  String get infoDropout =>
      'Regularization; randomly zeroes adapter weights during training';

  @override
  String get labelUseFp8 => 'Use FP8';

  @override
  String get subtitleUseFp8 => 'Use FP8 training when runtime supports it';

  @override
  String get infoUseFp8 =>
      'Reduces memory with 8-bit floating point; requires compatible GPU';

  @override
  String get labelLinearDim => 'Linear Dim';

  @override
  String get subtitleLinearDim => 'LoKR linear dimension';

  @override
  String get infoLinearDim =>
      'Kronecker decomposition dimension; similar to LoRA rank';

  @override
  String get labelLinearAlpha => 'Linear Alpha';

  @override
  String get subtitleLinearAlpha => 'LoKR linear alpha scaling factor';

  @override
  String get infoLinearAlpha =>
      'Scales the LoKR update; typically 2x linear dim';

  @override
  String get labelFactor => 'Factor';

  @override
  String get hintFactorAuto => '-1 for auto';

  @override
  String get infoFactor =>
      'Kronecker factorization factor; -1 for automatic selection';

  @override
  String get labelDecomposeBoth => 'Decompose Both';

  @override
  String get subtitleDecomposeBoth => 'Decompose both matrices';

  @override
  String get infoDecomposeBoth =>
      'Apply Kronecker decomposition to both weight matrices';

  @override
  String get labelUseTucker => 'Use Tucker';

  @override
  String get subtitleUseTucker => 'Use Tucker decomposition';

  @override
  String get infoUseTucker =>
      'Use Tucker decomposition for more efficient factorization';

  @override
  String get labelUseScalar => 'Use Scalar';

  @override
  String get subtitleUseScalar => 'Use scalar calibration';

  @override
  String get infoUseScalar =>
      'Add a learnable scalar multiplier for calibration';

  @override
  String get labelWeightDecompose => 'Weight Decompose';

  @override
  String get subtitleWeightDecompose => 'Enable DoRA mode';

  @override
  String get infoWeightDecompose =>
      'Enable DoRA (Weight-Decomposed Low-Rank Adaptation)';

  @override
  String get labelLearningRate => 'Learning Rate';

  @override
  String get infoLearningRate =>
      'Step size for the optimizer; LoRA ~1e-4, LoKR ~0.03';

  @override
  String get labelEpochs => 'Epochs';

  @override
  String get subtitleEpochs => 'Number of training epochs';

  @override
  String get infoEpochs =>
      'Full passes over the dataset; more epochs = longer training';

  @override
  String get labelBatchSize => 'Batch Size';

  @override
  String get subtitleBatchSize => 'Training batch size';

  @override
  String get infoBatchSize => 'Samples processed per step; higher = more VRAM';

  @override
  String get labelGradientAccumulation => 'Gradient Accumulation';

  @override
  String get subtitleGradientAccumulation => 'Gradient accumulation steps';

  @override
  String get infoGradientAccumulation =>
      'Simulates larger batches; effective batch = batch size x accumulation';

  @override
  String get labelSaveEveryNEpochs => 'Save Every N Epochs';

  @override
  String get subtitleSaveEveryNEpochs => 'Checkpoint save interval';

  @override
  String get infoSaveEveryNEpochs => 'Save a checkpoint every N epochs';

  @override
  String get subtitleTrainingShift => 'Training timestep shift';

  @override
  String get infoTrainingShift => 'Fixed at 3.0 for turbo model';

  @override
  String get infoSeed => 'Random seed for reproducibility';

  @override
  String get labelGradientCheckpointing => 'Gradient Checkpointing';

  @override
  String get subtitleGradientCheckpointing =>
      'Trade compute speed for lower VRAM usage';

  @override
  String get infoGradientCheckpointing =>
      'Recomputes activations to save VRAM; slower but uses less memory';

  @override
  String get labelOutputDirectory => 'Output Directory';

  @override
  String get infoOutputDirectory =>
      'Directory to save adapter checkpoints during training';

  @override
  String get buttonStartTraining => 'Start Training';

  @override
  String get buttonStopTraining => 'Stop Training';

  @override
  String get trainingLabelStatus => 'Status';

  @override
  String get trainingLabelEpoch => 'Epoch';

  @override
  String get trainingLabelStep => 'Step';

  @override
  String get trainingLabelLoss => 'Loss';

  @override
  String get trainingLabelSpeed => 'Speed';

  @override
  String trainingSpeedValue(String value) {
    return '$value steps/s';
  }

  @override
  String get trainingLabelETA => 'ETA';

  @override
  String trainingErrorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String trainingTensorboard(String url) {
    return 'TensorBoard: $url';
  }

  @override
  String get trainingStopRequested => 'Stop requested';

  @override
  String get trainingComplete => 'Training complete';

  @override
  String get errorInvalidLearningRate => 'Invalid learning rate';

  @override
  String get errorExportPathRequired => 'Export path is required';

  @override
  String get labelExportPath => 'Export Path';

  @override
  String get hintExportPath => '/path/to/export/lora';

  @override
  String get infoExportPath =>
      'Destination path for the final exported adapter';

  @override
  String get buttonExportLora => 'Export LoRA';

  @override
  String get exportingEllipsis => 'Exporting...';

  @override
  String get loraExportedSuccessfully => 'LoRA exported successfully';

  @override
  String get datasetSectionUpload => 'Upload Dataset Zip';

  @override
  String get buttonChooseZip => 'Choose .zip';

  @override
  String get labelDatasetName => 'Dataset Name';

  @override
  String get infoDatasetName => 'Name identifier for the dataset';

  @override
  String get labelCustomTag => 'Custom Tag';

  @override
  String get hintCustomTag => 'Optional tag for captions';

  @override
  String get infoCustomTag =>
      'Activation tag added to captions during training';

  @override
  String get labelTagPosition => 'Tag Position';

  @override
  String get infoTagPosition =>
      'Where to insert the custom tag relative to captions';

  @override
  String get labelAllInstrumental => 'All Instrumental';

  @override
  String get subtitleAllInstrumental => 'Mark all samples as instrumental';

  @override
  String get infoAllInstrumental => 'Treat all samples as having no vocals';

  @override
  String get uploadingEllipsis => 'Uploading...';

  @override
  String uploadedSamples(int count) {
    return 'Uploaded $count samples';
  }

  @override
  String get datasetSectionLoad => 'Load Existing Dataset';

  @override
  String get labelDatasetJsonPath => 'Dataset JSON Path';

  @override
  String get infoDatasetJsonPath =>
      'Path to a previously saved dataset.json on the server';

  @override
  String get buttonLoad => 'Load';

  @override
  String loadedSamples(int count) {
    return 'Loaded $count samples';
  }

  @override
  String get datasetSectionAutoLabel => 'Auto-Label';

  @override
  String get labelSkipMetas => 'Skip Metas';

  @override
  String get subtitleSkipMetas => 'Skip BPM/Key/TimeSig detection';

  @override
  String get infoSkipMetas =>
      'Skip BPM, key, and time signature detection to speed up labeling';

  @override
  String get labelFormatLyrics => 'Format Lyrics';

  @override
  String get subtitleFormatLyrics => 'Format lyrics via LLM';

  @override
  String get infoFormatLyrics => 'Reformat user-provided lyrics using the LLM';

  @override
  String get labelTranscribeLyrics => 'Transcribe Lyrics';

  @override
  String get subtitleTranscribeLyrics => 'Transcribe from audio';

  @override
  String get infoTranscribeLyrics =>
      'Transcribe lyrics from audio using speech recognition';

  @override
  String get labelOnlyUnlabeled => 'Only Unlabeled';

  @override
  String get subtitleOnlyUnlabeled => 'Only label unlabeled samples';

  @override
  String get infoOnlyUnlabeled => 'Skip samples that already have labels';

  @override
  String get labelSavePathOptional => 'Save Path (optional)';

  @override
  String get infoAutoLabelSavePath =>
      'Auto-save labeling progress to this JSON file';

  @override
  String get labelChunkSize => 'Chunk Size';

  @override
  String get infoChunkSize => 'Number of audio samples to encode per VAE batch';

  @override
  String get labelBatchSizeDataset => 'Batch Size';

  @override
  String get infoBatchSizeDataset => 'Samples processed per labeling batch';

  @override
  String get labelingEllipsis => 'Labeling...';

  @override
  String get buttonStartAutoLabel => 'Start Auto-Label';

  @override
  String get startingEllipsis => 'Starting...';

  @override
  String get processingEllipsis => 'Processing...';

  @override
  String get autoLabelingComplete => 'Auto-labeling complete';

  @override
  String get autoLabelingFailed => 'Auto-labeling failed';

  @override
  String datasetSectionSamples(int count) {
    return 'Samples ($count)';
  }

  @override
  String get datasetSectionSave => 'Save Dataset';

  @override
  String get labelSavePath => 'Save Path';

  @override
  String get infoSavePath => 'Path to save the dataset JSON file on the server';

  @override
  String get savingEllipsis => 'Saving...';

  @override
  String get datasetSaved => 'Dataset saved';

  @override
  String get datasetSectionPreprocess => 'Preprocess';

  @override
  String get infoOutputDirectoryPreprocess =>
      'Directory for preprocessed tensor files used in training';

  @override
  String get labelSkipExisting => 'Skip Existing';

  @override
  String get subtitleSkipExisting => 'Skip samples already preprocessed';

  @override
  String get infoSkipExisting =>
      'Skip samples that already have preprocessed tensors';

  @override
  String get preprocessingEllipsis => 'Processing...';

  @override
  String get buttonPreprocess => 'Preprocess';

  @override
  String get preprocessingComplete => 'Preprocessing complete';

  @override
  String get preprocessingFailed => 'Preprocessing failed';

  @override
  String get sampleLabelCaption => 'Caption';

  @override
  String get infoCaption => 'Text description of the music style and mood';

  @override
  String get sampleLabelGenre => 'Genre';

  @override
  String get infoGenre => 'Genre tags (e.g. rock, electronic, ambient)';

  @override
  String get sampleLabelLyrics => 'Lyrics';

  @override
  String get infoLyrics =>
      'Song lyrics or [Instrumental] for instrumental tracks';

  @override
  String get sampleLabelBpm => 'BPM';

  @override
  String get infoBpm => 'Beats per minute';

  @override
  String get sampleLabelKey => 'Key';

  @override
  String get infoKey => 'Musical key (e.g. C Major)';

  @override
  String get sampleLabelTimeSig => 'Time Sig';

  @override
  String get infoTimeSig => 'Time signature (e.g. 4/4)';

  @override
  String get sampleLabelLanguage => 'Language';

  @override
  String get infoLanguage => 'Language of the vocals (or unknown)';

  @override
  String get sampleLabelInstrumental => 'Instrumental';

  @override
  String get infoInstrumental => 'Whether this sample has no vocals';

  @override
  String get updatingEllipsis => 'Updating...';

  @override
  String get buttonUpdateSample => 'Update Sample';

  @override
  String get sampleUpdated => 'Sample updated';

  @override
  String get taskTypeGenerate =>
      'Generate a short music clip from a text prompt';

  @override
  String get taskTypeGenerateLong =>
      'Generate a longer music track from a text prompt';

  @override
  String get taskTypeUpload => 'Upload an existing audio file';

  @override
  String get taskTypeInfill => 'Fill in a section of audio between two points';

  @override
  String get taskTypeCover => 'Create a cover version in a different style';

  @override
  String get taskTypeExtract =>
      'Separate audio into individual stems (vocals, drums, etc.)';

  @override
  String get taskTypeAddStem =>
      'Add a new instrument or vocal layer to existing audio';

  @override
  String get taskTypeExtend => 'Extend an existing audio clip with new content';

  @override
  String get navLyrics => 'Lyrics';

  @override
  String get labelLyricBook => 'Lyric Book';

  @override
  String get tooltipOpenLyricBook => 'Open lyric book';

  @override
  String get lyricBookSearch => 'Search lyrics...';

  @override
  String get lyricBookNewSheet => 'New Lyric Sheet';

  @override
  String get lyricBookNoSheets => 'No lyric sheets yet';

  @override
  String get lyricBookLinkedSongs => 'Linked Songs';

  @override
  String get lyricBookNoLinkedSongs => 'No songs linked';

  @override
  String get lyricBookDeleteTitle => 'Delete Lyric Sheet';

  @override
  String get lyricBookDeleteContent =>
      'Are you sure you want to delete this lyric sheet? Your songs will not be deleted.';

  @override
  String get lyricBookUseForGeneration => 'Use for generation';

  @override
  String get lyricBookSaveToBook => 'Save to Lyric Book';

  @override
  String get lyricBookSaved => 'Saved to lyric book';

  @override
  String get lyricBookSearchSongs => 'Songs with matching lyrics';

  @override
  String get lyricBookReplaceTitle => 'Replace Lyrics';

  @override
  String get lyricBookReplaceContent =>
      'This will replace your current lyrics. Continue?';

  @override
  String get buttonReplace => 'Replace';

  @override
  String get systemHeading => 'System Information';

  @override
  String get systemInfoDescription =>
      'Hardware and browser details for troubleshooting.';

  @override
  String get systemBrowser => 'Browser';

  @override
  String get systemBrowserVersion => 'Browser Version';

  @override
  String get systemOperatingSystem => 'Operating System';

  @override
  String get systemGraphicsCard => 'Graphics Card';

  @override
  String get systemGraphicsDriver => 'Graphics Driver';

  @override
  String get systemMemory => 'Memory';

  @override
  String get systemCpu => 'CPU';

  @override
  String get systemCpuCores => 'CPU Cores';

  @override
  String get systemGpuMemory => 'GPU Memory';

  @override
  String get systemCopyAll => 'Copy All';

  @override
  String get systemCopied => 'Copied to clipboard';

  @override
  String get systemBranch => 'Branch';

  @override
  String get systemUnavailable => 'Unavailable';
}
