import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  String _targetClass = 'all';
  final _classes = ['all', '9', '10', '11', '12'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleCtrl.text.isEmpty || _messageCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required')),
      );
      return;
    }

    final provider = Provider.of<AdminProvider>(context, listen: false);
    final success = await provider.createAnnouncement(
      title: _titleCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
      imageUrl: _imageUrlCtrl.text.trim().isEmpty ? null : _imageUrlCtrl.text.trim(),
      targetClass: _targetClass,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Announcement sent!'), backgroundColor: Colors.green.shade700),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.createAnnouncementError ?? 'Failed to send'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Announcement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create Announcement', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A237E))),
            const SizedBox(height: 24),

            _field('Title', _titleCtrl, icon: Icons.title, maxLines: 1),
            const SizedBox(height: 16),
            _field('Message', _messageCtrl, icon: Icons.message_outlined, maxLines: 6, minLines: 3),
            const SizedBox(height: 16),
            _field('Image URL (optional)', _imageUrlCtrl, icon: Icons.image_outlined, maxLines: 1),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _targetClass,
              onChanged: (val) => setState(() => _targetClass = val!),
              decoration: InputDecoration(
                labelText: 'Target Class',
                prefixIcon: const Icon(Icons.group, color: Color(0xFF1565C0)),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
                ),
              ),
              items: _classes.map((c) => DropdownMenuItem(
                value: c,
                child: Text(c == 'all' ? 'All Classes' : 'Class $c'),
              )).toList(),
            ),
            const SizedBox(height: 32),

            Consumer<AdminProvider>(
              builder: (context, provider, _) => SizedBox(
                width: double.infinity,
                height: 56,
                child: provider.isCreatingAnnouncement
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
                    : ElevatedButton.icon(
                        onPressed: _send,
                        icon: const Icon(Icons.send, color: Colors.white),
                        label: const Text('Send Announcement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {required IconData icon, int? maxLines, int? minLines}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      minLines: minLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
