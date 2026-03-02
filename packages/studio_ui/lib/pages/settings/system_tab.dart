import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class SystemTab extends StatefulWidget {
  const SystemTab({super.key});

  @override
  State<SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<SystemTab> {
  static const _buildBranch =
      String.fromEnvironment('BUILD_BRANCH', defaultValue: 'dev');

  bool _copied = false;
  Map<String, String> _info = {};

  @override
  void initState() {
    super.initState();
    _collectInfo();
  }

  void _collectInfo() {
    final ua = web.window.navigator.userAgent;
    final browser = _parseBrowser(ua);
    final browserVersion = _parseBrowserVersion(ua);
    final os = _parseOS(ua);
    final cores = web.window.navigator.hardwareConcurrency;
    final deviceMemory = _getDeviceMemory();
    final gpu = _getGpuInfo();

    setState(() {
      _info = {
        'Branch': _buildBranch,
        'Browser': browser,
        'Browser Version': browserVersion,
        'Operating System': os,
        'Graphics Card': gpu['renderer'] ?? 'Unavailable',
        'Graphics Driver': gpu['vendor'] ?? 'Unavailable',
        'Memory': deviceMemory != null ? '$deviceMemory GB' : 'Unavailable',
        'CPU': _parseCpu(ua),
        'CPU Cores': '$cores',
        'GPU Memory': gpu['gpuMemory'] ?? 'Unavailable',
      };
    });
  }

  String _parseBrowser(String ua) {
    if (ua.contains('Edg/')) return 'Microsoft Edge';
    if (ua.contains('OPR/') || ua.contains('Opera')) return 'Opera';
    if (ua.contains('Chrome/') && !ua.contains('Edg/')) return 'Google Chrome';
    if (ua.contains('Firefox/')) return 'Firefox';
    if (ua.contains('Safari/') && !ua.contains('Chrome/')) return 'Safari';
    return 'Unknown';
  }

  String _parseBrowserVersion(String ua) {
    final patterns = [
      RegExp(r'Edg/([\d.]+)'),
      RegExp(r'OPR/([\d.]+)'),
      RegExp(r'Chrome/([\d.]+)'),
      RegExp(r'Firefox/([\d.]+)'),
      RegExp(r'Version/([\d.]+).*Safari'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(ua);
      if (match != null) return match.group(1) ?? 'Unknown';
    }
    return 'Unknown';
  }

  String _parseOS(String ua) {
    if (ua.contains('Windows NT 10.0')) return 'Windows 10/11';
    if (ua.contains('Windows NT 6.3')) return 'Windows 8.1';
    if (ua.contains('Windows NT 6.2')) return 'Windows 8';
    if (ua.contains('Windows NT 6.1')) return 'Windows 7';
    if (ua.contains('Mac OS X')) {
      final match = RegExp(r'Mac OS X ([\d_]+)').firstMatch(ua);
      if (match != null) {
        return 'macOS ${match.group(1)!.replaceAll('_', '.')}';
      }
      return 'macOS';
    }
    if (ua.contains('Linux')) return 'Linux';
    if (ua.contains('CrOS')) return 'Chrome OS';
    return 'Unknown';
  }

  String _parseCpu(String ua) {
    if (ua.contains('x86_64') || ua.contains('x64') || ua.contains('Win64')) {
      return 'x86_64';
    }
    if (ua.contains('arm64') || ua.contains('aarch64')) return 'ARM64';
    if (ua.contains('armv')) return 'ARM';
    if (ua.contains('x86')) return 'x86';
    return 'Unknown architecture';
  }

  double? _getDeviceMemory() {
    try {
      final nav = web.window.navigator as JSObject;
      final value = nav['deviceMemory'];
      if (value != null && value.isA<JSNumber>()) {
        return (value as JSNumber).toDartDouble;
      }
    } catch (_) {}
    return null;
  }

  Map<String, String> _getGpuInfo() {
    final result = <String, String>{};
    try {
      final canvas =
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      final gl = canvas.getContext('webgl2') ?? canvas.getContext('webgl');
      if (gl != null) {
        final ext = gl.callMethod(
          'getExtension'.toJS,
          'WEBGL_debug_renderer_info'.toJS,
        );
        if (ext != null && ext.isA<JSObject>()) {
          final extObj = ext as JSObject;
          final rendererEnum = extObj['UNMASKED_RENDERER_WEBGL'];
          final vendorEnum = extObj['UNMASKED_VENDOR_WEBGL'];

          if (rendererEnum != null) {
            final unmaskedRenderer = gl.callMethod(
              'getParameter'.toJS,
              rendererEnum,
            );
            if (unmaskedRenderer != null && unmaskedRenderer.isA<JSString>()) {
              result['renderer'] = (unmaskedRenderer as JSString).toDart;
            }
          }
          if (vendorEnum != null) {
            final unmaskedVendor = gl.callMethod(
              'getParameter'.toJS,
              vendorEnum,
            );
            if (unmaskedVendor != null && unmaskedVendor.isA<JSString>()) {
              result['vendor'] = (unmaskedVendor as JSString).toDart;
            }
          }
        }

        // Try NVX extension for GPU memory (NVIDIA GPUs in some browsers)
        final memExt = gl.callMethod(
          'getExtension'.toJS,
          'WEBGL_memory_info'.toJS,
        );
        if (memExt != null && memExt.isA<JSObject>()) {
          final memExtObj = memExt as JSObject;
          final memEnum =
              memExtObj['GPU_MEMORY_INFO_TOTAL_AVAILABLE_MEMORY_NVX'];
          if (memEnum != null) {
            final totalMem = gl.callMethod('getParameter'.toJS, memEnum);
            if (totalMem != null && totalMem.isA<JSNumber>()) {
              final mb = (totalMem as JSNumber).toDartDouble;
              if (mb > 1024) {
                result['gpuMemory'] =
                    '${(mb / 1024).toStringAsFixed(1)} GB';
              } else {
                result['gpuMemory'] = '${mb.toStringAsFixed(0)} MB';
              }
            }
          }
        }
      }
    } catch (_) {}
    return result;
  }

  void _copyAll() {
    final buffer = StringBuffer();
    buffer.writeln('=== Studio System Information ===');
    for (final entry in _info.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }
    buffer.writeln('User Agent: ${web.window.navigator.userAgent}');
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final unavailable = s.systemUnavailable;

    final localizedLabels = {
      'Branch': s.systemBranch,
      'Browser': s.systemBrowser,
      'Browser Version': s.systemBrowserVersion,
      'Operating System': s.systemOperatingSystem,
      'Graphics Card': s.systemGraphicsCard,
      'Graphics Driver': s.systemGraphicsDriver,
      'Memory': s.systemMemory,
      'CPU': s.systemCpu,
      'CPU Cores': s.systemCpuCores,
      'GPU Memory': s.systemGpuMemory,
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                s.systemHeading,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.settingsHeading,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 28,
                child: OutlinedButton.icon(
                  onPressed: _copyAll,
                  icon: Icon(
                    _copied ? Icons.check : Icons.copy,
                    size: 14,
                    color: _copied ? AppColors.accent : AppColors.textMuted,
                  ),
                  label: Text(
                    _copied ? s.systemCopied : s.systemCopyAll,
                    style: TextStyle(
                      fontSize: 12,
                      color: _copied ? AppColors.accent : AppColors.text,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: BorderSide(
                      color: _copied ? AppColors.accent : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.systemInfoDescription,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _info.entries.map((entry) {
                final label = localizedLabels[entry.key] ?? entry.key;
                final value =
                    entry.value == 'Unavailable' ? unavailable : entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          value,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
