import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:wine_launcher/models/game.dart';
import 'package:wine_launcher/models/wine_prefix.dart';
import 'package:provider/provider.dart';
import 'package:wine_launcher/models/providers.dart';
import 'package:path/path.dart' as p;

class AddGameDialog extends StatefulWidget {
  final Game? existingGame;
  final List<WinePrefix> availablePrefixes;
  final String gamesPath;
  final Set<String> existingCategories;

  const AddGameDialog({
    super.key,
    this.existingGame,
    required this.availablePrefixes,
    required this.gamesPath,
    this.existingCategories = const {},
  });

  @override
  State<AddGameDialog> createState() => _AddGameDialogState();
}

class _AddGameDialogState extends State<AddGameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _exePathController = TextEditingController();
  WinePrefix? _selectedPrefix;
  String? _coverImagePath;

  @override
  void initState() {
    super.initState();
    if (widget.existingGame != null) {
      _nameController.text = widget.existingGame!.name;
      _categoryController.text = widget.existingGame!.category;
      _exePathController.text = widget.existingGame!.exePath;
      _coverImagePath = widget.existingGame!.coverImagePath;
      
      // Find the matching prefix from available prefixes
      if (widget.existingGame!.hasPrefix && widget.availablePrefixes.isNotEmpty) {
        _selectedPrefix = widget.availablePrefixes.firstWhere(
          (p) => p.path == widget.existingGame!.prefixPath,
          orElse: () => widget.availablePrefixes.first,
        );
      } else {
        // Default to first prefix
        _selectedPrefix = widget.availablePrefixes.isNotEmpty 
          ? widget.availablePrefixes.first 
          : null;
      }
    } else {
      // For new games, default to first prefix
      _selectedPrefix = widget.availablePrefixes.isNotEmpty 
        ? widget.availablePrefixes.first 
        : null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _exePathController.dispose();
    super.dispose();
  }

  Future<void> _selectExe() async {
    // First ensure we have a valid game directory
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final gameDir = Directory(p.join(settings.gamesPath, _nameController.text));
    
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a game name first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Create game directory if it doesn't exist
    if (!await gameDir.exists()) {
      await gameDir.create(recursive: true);
    }

    // Open file picker in game directory
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['exe'],
      initialDirectory: gameDir.path,
      lockParentWindow: true,
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      // Verify file is within game directory
      if (!file.path.startsWith(gameDir.path)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an executable within the game folder'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      setState(() {
        _exePathController.text = file.path;
      });
    }
  }

  Future<void> _selectCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        _coverImagePath = result.files.single.path!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingGame != null ? 'Edit Game' : 'Add Game'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter game name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Category',
                  hintText: 'Enter game category',
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    tooltip: 'Select existing category',
                    onSelected: (String value) {
                      setState(() {
                        _categoryController.text = value;
                      });
                    },
                    itemBuilder: (BuildContext context) {
                      return widget.existingCategories.map((String category) {
                        return PopupMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _exePathController,
                      decoration: const InputDecoration(
                        labelText: 'Executable Path',
                        hintText: 'Select game executable',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select an executable';
                        }
                        return null;
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_open),
                    onPressed: _selectExe,
                    tooltip: 'Select Executable',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<WinePrefix>(
                value: _selectedPrefix,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Wine Prefix',
                  hintText: 'Select a prefix',
                ),
                items: widget.availablePrefixes.map((prefix) {
                  return DropdownMenuItem<WinePrefix>(
                    value: prefix,
                    child: Row(
                      children: [
                        Icon(
                          prefix.isProton ? Icons.sports_esports : Icons.wine_bar,
                          color: prefix.isProton ? Colors.purple : Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${prefix.name} (${prefix.isProton ? 'Proton' : 'Wine'})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPrefix = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a prefix';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: _coverImagePath != null
                    ? Image.file(
                        File(_coverImagePath!),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image),
                title: const Text('Cover Image'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _selectCoverImage,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final game = Game(
                id: widget.existingGame?.id,
                name: _nameController.text,
                category: _categoryController.text,
                exePath: _exePathController.text,
                prefixPath: _selectedPrefix?.path,
                isProton: _selectedPrefix?.isProton,
                coverImagePath: _coverImagePath,
                environment: widget.existingGame?.environment ?? {},
                launchOptions: widget.existingGame?.launchOptions ?? {},
              );
              Navigator.pop(context, game);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
} 