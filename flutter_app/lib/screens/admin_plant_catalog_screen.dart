import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/plant_type_model.dart';
import '../services/auth_provider.dart';
import '../services/plant_provider.dart';

/// Admin screen for managing the plant species catalog
/// Only accessible by admin role
class AdminPlantCatalogScreen extends StatefulWidget {
  final bool embedded;

  const AdminPlantCatalogScreen({super.key, this.embedded = false});

  @override
  State<AdminPlantCatalogScreen> createState() =>
      _AdminPlantCatalogScreenState();
}

class _AdminPlantCatalogScreenState extends State<AdminPlantCatalogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlantProvider>().loadPlantTypes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Security check - only admin can access
    if (!authProvider.isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text('Nincs jogosultsága ehhez az oldalhoz'),
        ),
      );
    }

    final body = Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        if (plantProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (plantProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(plantProvider.error!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => plantProvider.loadPlantTypes(),
                  child: const Text('Újrapróbálás'),
                ),
              ],
            ),
          );
        }

        if (plantProvider.plantTypes.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () => plantProvider.loadPlantTypes(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plantProvider.plantTypes.length,
            itemBuilder: (context, index) =>
                _buildPlantTypeCard(plantProvider.plantTypes[index]),
          ),
        );
      },
    );

    // Embedded mode - no scaffold, just body
    if (widget.embedded) {
      return Stack(
        children: [
          body,
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: () => _showAddPlantTypeDialog(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add),
              label: const Text('Új növényfaj'),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Növénykatalógus kezelése'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<PlantProvider>().loadPlantTypes(),
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPlantTypeDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Új növényfaj'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.eco_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Üres katalógus',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adja hozzá az első növényfajt a katalógushoz',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddPlantTypeDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Növényfaj hozzáadása'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantTypeCard(PlantType plantType) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.success.withOpacity(0.2),
          child: const Icon(Icons.eco, color: AppColors.success),
        ),
        title: Text(
          plantType.plantName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          plantType.scientificName,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Requirements
                const Text(
                  'Igények:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildRequirementRow(
                  Icons.thermostat,
                  'Homerseklet',
                  '${plantType.reqTemperature.round()}°C',
                  Colors.orange,
                ),
                _buildRequirementRow(
                  Icons.water_drop,
                  'Talajnedvesseg',
                  '${plantType.reqMoisture}%',
                  Colors.blue,
                ),
                _buildRequirementRow(
                  Icons.wb_sunny,
                  'Fenyigeny',
                  '${plantType.reqBrightness.round()} lux',
                  Colors.amber,
                ),
                _buildRequirementRow(
                  Icons.opacity,
                  'Paratartalom',
                  '${plantType.reqHumidity.round()}%',
                  Colors.teal,
                ),

                if (plantType.description != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Leírás:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(plantType.description!),
                ],

                if (plantType.careInstructions != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Gondozási útmutató:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(plantType.careInstructions!),
                ],

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          _showEditPlantTypeDialog(context, plantType),
                      icon: const Icon(Icons.edit),
                      label: const Text('Szerkesztés'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(context, plantType),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Törlés',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(
      IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text('$label: '),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _showAddPlantTypeDialog(BuildContext context) async {
    final result = await showDialog<PlantType>(
      context: context,
      builder: (context) => const _PlantTypeFormDialog(),
    );

    if (result != null && mounted) {
      final plantProvider = context.read<PlantProvider>();
      final success = await plantProvider.addPlantTypeToCatalog(result);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Novenyfaj sikeresen hozzaadva'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  plantProvider.error ?? 'Nem sikerult hozzaadni a novenyfajt'),
              backgroundColor: Colors.red,
            ),
          );
          plantProvider.clearError();
        }
      }
    }
  }

  Future<void> _showEditPlantTypeDialog(
      BuildContext context, PlantType plantType) async {
    final result = await showDialog<PlantType>(
      context: context,
      builder: (context) => _PlantTypeFormDialog(plantType: plantType),
    );

    if (result != null && mounted) {
      final plantProvider = context.read<PlantProvider>();
      final success =
          await plantProvider.updatePlantSpecies(plantType.id, result);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Novenyfaj sikeresen frissitve'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(plantProvider.error ??
                  'Nem sikerult frissiteni a novenyfajt'),
              backgroundColor: Colors.red,
            ),
          );
          plantProvider.clearError();
        }
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, PlantType plantType) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Növényfaj törlése'),
        content: Text(
          'Biztosan törölni szeretné a(z) "${plantType.plantName}" növényfajt?\n\n'
          'Ez a művelet nem visszavonható.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mégsem'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final plantProvider = context.read<PlantProvider>();
      final success = await plantProvider.deletePlantSpecies(plantType.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Novenyfaj torolve'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  plantProvider.error ?? 'Nem sikerult torolni a novenyfajt'),
              backgroundColor: Colors.red,
            ),
          );
          plantProvider.clearError();
        }
      }
    }
  }
}

/// Dialog form for adding/editing plant types
class _PlantTypeFormDialog extends StatefulWidget {
  final PlantType? plantType;

  const _PlantTypeFormDialog({this.plantType});

  @override
  State<_PlantTypeFormDialog> createState() => _PlantTypeFormDialogState();
}

class _PlantTypeFormDialogState extends State<_PlantTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _scientificNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _careInstructionsController;
  late TextEditingController _brightnessController;

  late int _reqTemperature;
  late int _reqMoisture;
  late int _reqHumidity;

  bool get isEditing => widget.plantType != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.plantType?.plantName ?? '');
    _scientificNameController =
        TextEditingController(text: widget.plantType?.scientificName ?? '');
    _descriptionController =
        TextEditingController(text: widget.plantType?.description ?? '');
    _careInstructionsController =
        TextEditingController(text: widget.plantType?.careInstructions ?? '');
    _brightnessController = TextEditingController(
        text: (widget.plantType?.reqBrightness.round() ?? 5000).toString());

    _reqTemperature = widget.plantType?.reqTemperature.round() ?? 22;
    _reqMoisture = widget.plantType?.reqMoisture ?? 50;
    _reqHumidity = widget.plantType?.reqHumidity.round() ?? 50;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scientificNameController.dispose();
    _descriptionController.dispose();
    _careInstructionsController.dispose();
    _brightnessController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Növényfaj szerkesztése' : 'Új növényfaj'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Név *',
                    hintText: 'pl. Monstera deliciosa',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kötelező mező';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Scientific name
                TextFormField(
                  controller: _scientificNameController,
                  decoration: const InputDecoration(
                    labelText: 'Tudományos név *',
                    hintText: 'pl. Monstera deliciosa',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kötelező mező';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Requirements section
                const Text(
                  'Igenyek',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),

                // Temperature slider (whole numbers)
                _buildIntSliderField(
                  label: 'Homerseklet',
                  value: _reqTemperature,
                  min: 10,
                  max: 35,
                  suffix: '\u00b0C',
                  onChanged: (value) => setState(() => _reqTemperature = value),
                ),

                // Moisture slider (whole numbers)
                _buildIntSliderField(
                  label: 'Talajnedvesseg',
                  value: _reqMoisture,
                  min: 0,
                  max: 100,
                  suffix: '%',
                  onChanged: (value) => setState(() => _reqMoisture = value),
                ),

                // Brightness text field (lux - no constraint)
                const SizedBox(height: 8),
                TextFormField(
                  controller: _brightnessController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fenyigeny (lux) *',
                    hintText: 'pl. 5000',
                    border: OutlineInputBorder(),
                    suffixText: 'lux',
                    helperText:
                        'Tipikus ertekek: Arnyekos: 500-2000, Kozepes: 2000-10000, Napsutos: 10000+',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kotelezo mezo';
                    }
                    final parsed = int.tryParse(value);
                    if (parsed == null || parsed < 0) {
                      return 'Ervenyes pozitiv szamot adjon meg';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Humidity slider (whole numbers)
                _buildIntSliderField(
                  label: 'Paratartalom',
                  value: _reqHumidity,
                  min: 0,
                  max: 100,
                  suffix: '%',
                  onChanged: (value) => setState(() => _reqHumidity = value),
                ),

                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Leírás',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Care instructions
                TextFormField(
                  controller: _careInstructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Gondozási útmutató',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Megsem'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Mentes' : 'Hozzaadas'),
        ),
      ],
    );
  }

  Widget _buildIntSliderField({
    required String label,
    required int value,
    required int min,
    required int max,
    required String suffix,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '$value$suffix',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final brightness = int.tryParse(_brightnessController.text.trim()) ?? 5000;

    final plantType = PlantType(
      id: widget.plantType?.id ?? 0,
      plantName: _nameController.text.trim(),
      scientificName: _scientificNameController.text.trim(),
      reqBrightness: brightness.toDouble(),
      reqHumidity: _reqHumidity.toDouble(),
      reqTemperature: _reqTemperature.toDouble(),
      reqMoisture: _reqMoisture,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      careInstructions: _careInstructionsController.text.trim().isEmpty
          ? null
          : _careInstructionsController.text.trim(),
    );

    Navigator.pop(context, plantType);
  }
}
