import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onBackToLogin;
  const RegisterScreen({super.key, required this.onBackToLogin});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _studentPhoneCtrl = TextEditingController();
  final _guardianPhoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  String _gender = 'Male';
  String _classNo = '10';
  String _language = 'English';
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;

  final _classes = ['9', '10', '11', '12'];
  final _languages = ['Bengali', 'English', 'Both'];
  final _genders = ['Male', 'Female', 'Other'];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _fatherNameCtrl.dispose();
    _studentPhoneCtrl.dispose();
    _guardianPhoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00BCD4),
            surface: Color(0xFF1A2744),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dobCtrl.text = '${picked.day}/${picked.month}/${picked.year}';
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      final response = await api.register({
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'dateOfBirth': _dobCtrl.text.trim(),
        'gender': _gender,
        'classNo': int.parse(_classNo),
        'language': _language,
        'fatherName': _fatherNameCtrl.text.trim(),
        'studentPhone': _studentPhoneCtrl.text.trim(),
        'guardianPhone': _guardianPhoneCtrl.text.trim(),
        'password': _passwordCtrl.text,
      });

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Registration successful! Please wait for admin approval.'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
          widget.onBackToLogin();
        } else {
          _showError('Registration failed. Please try again.');
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF00BCD4)),
          onPressed: widget.onBackToLogin,
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Personal Information'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _darkField('First Name', _firstNameCtrl, icon: Icons.person_outline)),
                    const SizedBox(width: 12),
                    Expanded(child: _darkField('Last Name', _lastNameCtrl, icon: Icons.person_outline)),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: _darkField('Date of Birth', _dobCtrl,
                      icon: Icons.calendar_today,
                      hint: 'dd/mm/yyyy',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _darkField('Father\'s Name', _fatherNameCtrl, icon: Icons.family_restroom),
                const SizedBox(height: 16),
                _dropdownField('Gender', _gender, _genders, (val) => setState(() => _gender = val!),
                    icon: Icons.wc),
                const SizedBox(height: 24),

                _sectionTitle('Academic Details'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _dropdownField('Class', _classNo, _classes,
                        (val) => setState(() => _classNo = val!), icon: Icons.class_),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dropdownField('Medium', _language, _languages,
                        (val) => setState(() => _language = val!), icon: Icons.translate),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _sectionTitle('Contact Information'),
                const SizedBox(height: 16),
                _darkField('Student\'s Phone', _studentPhoneCtrl,
                  icon: Icons.phone, keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Required';
                    if (val.length != 10) return 'Must be 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _darkField('Guardian\'s Phone', _guardianPhoneCtrl,
                  icon: Icons.phone_in_talk_outlined, keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Required';
                    if (val.length != 10) return 'Must be 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                _sectionTitle('Security'),
                const SizedBox(height: 16),
                _passwordField('Password', _passwordCtrl, _passwordVisible,
                  () => setState(() => _passwordVisible = !_passwordVisible)),
                const SizedBox(height: 16),
                _passwordField('Confirm Password', _confirmPasswordCtrl, _confirmPasswordVisible,
                  () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible)),
                const SizedBox(height: 36),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BCD4)))
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00BCD4), Color(0xFF006064)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ElevatedButton(
                            onPressed: _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              'Register Account',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? ', style: TextStyle(color: Color(0xFF8897AE))),
                    TextButton(
                      onPressed: widget.onBackToLogin,
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF00BCD4), padding: EdgeInsets.zero),
                      child: const Text('Login', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00BCD4),
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: const Color(0xFF2D3748)),
      ],
    );
  }

  Widget _darkField(
    String label,
    TextEditingController ctrl, {
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF8897AE)),
        hintStyle: const TextStyle(color: Color(0xFF4A5568)),
        prefixIcon: Icon(icon, color: const Color(0xFF00BCD4), size: 20),
        filled: true,
        fillColor: const Color(0xFF1A2744),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D3748))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D3748))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
        errorStyle: const TextStyle(color: Colors.redAccent),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator ?? (val) => (val == null || val.isEmpty) ? 'Required' : null,
    );
  }

  Widget _passwordField(String label, TextEditingController ctrl, bool visible, VoidCallback toggle) {
    return TextFormField(
      controller: ctrl,
      obscureText: !visible,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8897AE)),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00BCD4), size: 20),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF8897AE)),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: const Color(0xFF1A2744),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D3748))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D3748))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (val) {
        if (val == null || val.isEmpty) return 'Required';
        if (val.length < 6) return 'Minimum 6 characters';
        return null;
      },
    );
  }

  Widget _dropdownField(String label, String value, List<String> options, ValueChanged<String?> onChanged, {required IconData icon}) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF1A2744),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8897AE)),
        prefixIcon: Icon(icon, color: const Color(0xFF00BCD4), size: 20),
        filled: true,
        fillColor: const Color(0xFF1A2744),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D3748))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D3748))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
    );
  }
}
