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
                  'Hőmérséklet',
                  '${plantType.reqTemperature.toStringAsFixed(1)}°C',
                  Colors.orange,
                ),
                _buildRequirementRow(
                  Icons.water_drop,
                  'Talajnedvesség',
                  '${plantType.reqMoisture}%',
                  Colors.blue,
                ),
                _buildRequirementRow(
                  Icons.wb_sunny,
                  'Fényigény',
                  '${plantType.reqBrightness.toStringAsFixed(0)}%',
                  Colors.amber,
                ),
                _buildRequirementRow(
                  Icons.opacity,
                  'Páratartalom',
                  '${plantType.reqHumidity.toStringAsFixed(0)}%',
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
      final success =
          await context.read<PlantProvider>().addPlantTypeToCatalog(result);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Növényfaj sikeresen hozzáadva'),
            backgroundColor: Colors.green,
          ),
        );
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
      final success = await context
          .read<PlantProvider>()
          .updatePlantSpecies(plantType.id, result);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Növényfaj sikeresen frissítve'),
            backgroundColor: Colors.green,
          ),
        );
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
      final success =
          await context.read<PlantProvider>().deletePlantSpecies(plantType.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Növényfaj törölve'),
            backgroundColor: Colors.green,
          ),
        );
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

  late double _reqTemperature;
  late int _reqMoisture;
  late double _reqBrightness;
  late double _reqHumidity;

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

    _reqTemperature = widget.plantType?.reqTemperature ?? 22.0;
    _reqMoisture = widget.plantType?.reqMoisture ?? 50;
    _reqBrightness = widget.plantType?.reqBrightness ?? 50.0;
    _reqHumidity = widget.plantType?.reqHumidity ?? 50.0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scientificNameController.dispose();
    _descriptionController.dispose();
    _careInstructionsController.dispose();
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
                  'Igények',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),

                // Temperature slider
                _buildSliderField(
                  label: 'Hőmérséklet',
                  value: _reqTemperature,
                  min: 10,
                  max: 35,
                  suffix: '°C',
                  onChanged: (value) => setState(() => _reqTemperature = value),
                ),

                // Moisture slider
                _buildSliderField(
                  label: 'Talajnedvesség',
                  value: _reqMoisture.toDouble(),
                  min: 0,
                  max: 100,
                  suffix: '%',
                  onChanged: (value) =>
                      setState(() => _reqMoisture = value.round()),
                ),

                // Brightness slider
                _buildSliderField(
                  label: 'Fényigény',
                  value: _reqBrightness,
                  min: 0,
                  max: 100,
                  suffix: '%',
                  onChanged: (value) => setState(() => _reqBrightness = value),
                ),

                // Humidity slider
                _buildSliderField(
                  label: 'Páratartalom',
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
          child: const Text('Mégsem'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Mentés' : 'Hozzáadás'),
        ),
      ],
    );
  }

  Widget _buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '${value.toStringAsFixed(suffix == '°C' ? 1 : 0)}$suffix',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final plantType = PlantType(
      id: widget.plantType?.id ?? 0,
      plantName: _nameController.text.trim(),
      scientificName: _scientificNameController.text.trim(),
      reqBrightness: _reqBrightness,
      reqHumidity: _reqHumidity,
      reqTemperature: _reqTemperature,
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
