import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _baseUrlController;
  String? _currentOverride;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _loadCurrentBaseUrl();
  }

  Future<void> _loadCurrentBaseUrl() async {
    try {
      final override = await AuthStorageService.getBaseUrlOverride();
      setState(() {
        _currentOverride = override;
        _baseUrlController.text = override ?? AppConstants.baseUrl;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
      );
    }
  }

  Future<void> _saveBaseUrl() async {
    try {
      final url = _baseUrlController.text.trim();
      if (url.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base URL cannot be empty')),
        );
        return;
      }
      await AuthStorageService.saveBaseUrlOverride(url);
      if (!mounted) return;
      setState(() => _currentOverride = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base URL saved. Restart app to apply.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving base URL: $e')),
      );
    }
  }

  Future<void> _clearOverride() async {
    try {
      await AuthStorageService.saveBaseUrlOverride('');
      if (!mounted) return;
      setState(() {
        _currentOverride = null;
        _baseUrlController.text = AppConstants.baseUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Override cleared. Using default URL.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing override: $e')),
      );
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF006064),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'API Base URL Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Default: ${AppConstants.baseUrl}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'Manual Override (optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText: 'Base URL',
                hintText: 'e.g., http://localhost:5000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _saveBaseUrl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006064),
                  ),
                  child: const Text('Save Override'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _clearOverride,
                  child: const Text('Clear Override'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Current Status',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Using: ${_currentOverride ?? AppConstants.baseUrl}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentOverride == null
                        ? 'Default URL active'
                        : 'Custom override active',
                    style: TextStyle(
                      fontSize: 12,
                      color: _currentOverride == null ? Colors.blue : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
