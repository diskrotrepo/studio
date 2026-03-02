import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/picked_file.dart';
import '../theme/app_theme.dart';

class FilePickerField extends StatelessWidget {
  final PickedFile? selectedFile;
  final bool required;
  final ValueChanged<PickedFile?> onFileSelected;
  final String label;

  const FilePickerField({
    super.key,
    this.selectedFile,
    this.required = false,
    required this.onFileSelected,
    this.label = 'Select MIDI file',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = selectedFile != null;
    final fileName = hasFile ? selectedFile!.name : null;

    return InkWell(
      onTap: () async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mid', 'midi'],
          withData: true,
        );
        if (result != null && result.files.single.bytes != null) {
          onFileSelected(PickedFile(
            bytes: result.files.single.bytes!,
            name: result.files.single.name,
          ));
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasFile
                ? AppColors.brand.withValues(alpha: 0.5)
                : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
          color: AppColors.surfaceHigh,
        ),
        child: Row(
          children: [
            Icon(
              hasFile ? Icons.audio_file : Icons.upload_file,
              color: hasFile ? AppColors.brand : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile ? fileName! : label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasFile ? AppColors.text : AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (required && !hasFile)
                    Text(
                      'Required',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.controlBlue,
                      ),
                    ),
                ],
              ),
            ),
            if (hasFile)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => onFileSelected(null),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
