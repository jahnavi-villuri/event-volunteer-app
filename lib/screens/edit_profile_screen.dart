import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final int userId;
  final String name;
  final String studentId;

  const EditProfileScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.studentId,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _studentIdController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _studentIdController = TextEditingController(text: widget.studentId);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final updated = await ApiService.updateProfile(
        userId: widget.userId,
        name: _nameController.text.trim(),
        studentId: _studentIdController.text.trim(),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your name'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _studentIdController,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Student ID',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your student ID'
                  : null,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SAVE PROFILE'),
            ),
          ],
        ),
      ),
    );
  }
}
