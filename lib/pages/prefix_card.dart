import 'package:flutter/material.dart';
import 'dart:io';
import '../utils/wine_utils.dart';  // Create this file for wine-related functions
import 'package:file_picker/file_picker.dart';

class PrefixCard extends StatelessWidget {
  final String name;
  final String type;
  final String path;
  final String bits;

  const PrefixCard({
    super.key,
    required this.name,
    required this.type,
    required this.path,
    required this.bits,
  });

  Future<void> _applyControllerFix(BuildContext context) async {
    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Applying controller fix...'),
            ],
          ),
        ),
      );

      // Apply registry fixes
      final process = await Process.run('wine', [
        'reg',
        'add',
        'HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Services\\winebus',
        '/v',
        'DisableHidraw',
        '/t',
        'REG_DWORD',
        '/d',
        '1'
      ], environment: {
        'WINEPREFIX': path
      });

      if (process.exitCode == 0) {
        await Process.run('wine', [
          'reg',
          'add',
          'HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Services\\winebus',
          '/v',
          'Enable SDL',
          '/t',
          'REG_DWORD',
          '/d',
          '1'
        ], environment: {
          'WINEPREFIX': path
        });
      }

      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Controller fix applied successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying controller fix: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectAndRunExe(BuildContext context) async {
    // Add file picker functionality
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['exe'],
      dialogTitle: 'Select EXE to run',
    );

    if (result != null && result.files.single.path != null && context.mounted) {
      try {
        await Process.run('wine', [result.files.single.path!], 
          environment: {'WINEPREFIX': path}
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error running EXE: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(type == 'Wine' ? Icons.wine_bar : Icons.sports_esports),
            title: Text(name),
            subtitle: Text('$type $bits'),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Winecfg'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => WineUtils.runWinecfg(path),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.build),
                label: const Text('Winetricks'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => WineUtils.runWinetricks(path),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.folder),
                label: const Text('Explorer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => WineUtils.openExplorer(path),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_note),
                label: const Text('Regedit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => WineUtils.runRegedit(path),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.gamepad),
                label: const Text('Controller Fix'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _applyControllerFix(context),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run EXE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _selectAndRunExe(context),
              ),
              if (!type.toLowerCase().contains('proton')) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.build),
                  label: const Text('Install VC++'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => WineUtils.installVC(path),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
} 