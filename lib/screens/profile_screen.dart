import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/poultry_provider.dart';
import '../widgets/app_shell.dart';

class ProfileScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onEmbeddedBack;

  const ProfileScreen({super.key, this.embedded = false, this.onEmbeddedBack});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _age = TextEditingController();
  String? _avatarBase64;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await context.read<PoultryProvider>().fetchUserProfile();
      final user = FirebaseAuth.instance.currentUser;
      _name.text = (data['displayName']?.toString().trim().isNotEmpty == true)
          ? data['displayName'].toString().trim()
          : (user?.displayName ?? '');
      _email.text = (data['email']?.toString().trim().isNotEmpty == true)
          ? data['email'].toString().trim()
          : (user?.email ?? '');
      _mobile.text = data['mobileNumber']?.toString() ?? '';
      final age = data['age'];
      _age.text = age == null ? '' : age.toString();
      _avatarBase64 = data['avatarBase64']?.toString();
    } catch (_) {
      final user = FirebaseAuth.instance.currentUser;
      _name.text = user?.displayName ?? '';
      _email.text = user?.email ?? '';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Profile photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.camera_alt_outlined)),
              title: const Text('Take a photo'),
              subtitle: const Text('Use your device camera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.photo_library_outlined)),
              title: const Text('Choose from photos'),
              subtitle: const Text('Select an existing photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 75, maxWidth: 600, maxHeight: 600);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return;
    final encoded = base64Encode(bytes);
    if (encoded.length > 900000) {
      if (mounted) _snack('Please choose a smaller profile image.');
      return;
    }
    setState(() => _avatarBase64 = encoded);
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final mobile = _mobile.text.trim();
    final ageText = _age.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);
    if (ageText.isNotEmpty && age == null) {
      _snack('Enter a valid age.');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<PoultryProvider>().updateUserProfile(
        displayName: name,
        email: email,
        mobileNumber: mobile,
        age: age,
        avatarBase64: _avatarBase64,
      );
      if (!mounted) return;
      await FirebaseAuth.instance.currentUser?.reload();
      _snack('Profile updated successfully.');
      setState(() {});
    } on FirebaseAuthException catch (e) {
      final message = e.code == 'requires-recent-login'
          ? 'Changing email requires a recent sign-in. Please sign out and sign in again, then update the email.'
          : (e.message ?? 'Unable to update your profile.');
      _snack(message);
    } catch (e) {
      _snack('Unable to update profile: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final loading = const Center(child: CircularProgressIndicator());
      if (widget.embedded) return loading;
      return PoultryAppShell(title: 'My Profile', subtitle: 'Personal account information', onBack: () => Navigator.maybePop(context), child: loading);
    }

    final user = FirebaseAuth.instance.currentUser;
    final image = _avatarBase64 == null || _avatarBase64!.isEmpty ? null : MemoryImage(base64Decode(_avatarBase64!));
    final displayName = _name.text.trim().isEmpty ? 'User' : _name.text.trim();
    final email = user?.email ?? _email.text.trim();

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;
        if (mobile) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFB9DEC8), width: 3),
                        ),
                        child: ClipOval(
                          child: image == null
                              ? Container(color: const Color(0xFFE5F1EB), alignment: Alignment.center, child: const Icon(Icons.person, size: 58, color: Color(0xFF087A4F)))
                              : Image(image: image, fit: BoxFit.cover),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Color(0xFF087A4F), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text(displayName, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF162A21)))),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 3),
                Center(child: Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF75867D)))),
              ],
              const SizedBox(height: 24),
              _profileMenuCard([
                _profileMenu('person_outline', 'Personal information', 'Name, mobile number and age', () => _showEditDetails()),
                _profileMenu('photo_camera_outlined', 'Profile photo', 'Change your profile picture', _pickAvatar),
                _profileMenu('security_outlined', 'Account & security', 'Email and sign-in information', () => _showSecurityInfo()),
              ]),
              const SizedBox(height: 14),
              _profileDetailsCard(),
            ],
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _profileDetailsCard()),
            const SizedBox(width: 16),
            Expanded(child: _profileEditCard()),
          ]),
        );
      },
    );

    if (widget.embedded) return content;
    return PoultryAppShell(title: 'My Profile', subtitle: 'Personal account information', onBack: () => Navigator.maybePop(context), child: content);
  }

  Widget _profileMenu(String iconName, String title, String subtitle, VoidCallback onTap) {
    final icons = <String, IconData>{
      'person_outline': Icons.person_outline,
      'photo_camera_outlined': Icons.photo_camera_outlined,
      'security_outlined': Icons.security_outlined,
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFE7F6EE), borderRadius: BorderRadius.circular(12)), child: Icon(icons[iconName], color: const Color(0xFF087A4F))),
      title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF75867D))),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A39B)),
      onTap: onTap,
    );
  }

  Widget _profileMenuCard(List<Widget> children) => Card(margin: EdgeInsets.zero, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE1E9E4))), child: Column(children: children));

  Widget _profileDetailsCard() => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('ACCOUNT DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: Color(0xFF7A8B83))),
    const SizedBox(height: 12),
    _detailRow(Icons.person_outline, 'Full Name', _name.text.isEmpty ? 'Not set' : _name.text),
    _detailRow(Icons.email_outlined, 'Email', _email.text.isEmpty ? 'Not available' : _email.text),
    _detailRow(Icons.phone_outlined, 'Mobile', _mobile.text.isEmpty ? 'Not set' : _mobile.text),
    _detailRow(Icons.cake_outlined, 'Age', _age.text.isEmpty ? 'Not set' : _age.text),
  ]));

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, size: 19, color: const Color(0xFF0E9F6E)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF75867D),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2D24),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _profileEditCard() => AppCard(child: Column(children: [
    _field(_name, 'Full Name', Icons.person_outline), const SizedBox(height: 10),
    _field(_email, 'Email Address', Icons.email_outlined, keyboard: TextInputType.emailAddress, readOnly: true), const SizedBox(height: 10),
    _field(_mobile, 'Mobile Number', Icons.phone_outlined, keyboard: TextInputType.phone), const SizedBox(height: 10),
    _field(_age, 'Age', Icons.cake_outlined, keyboard: TextInputType.number), const SizedBox(height: 16),
    SizedBox(width: double.infinity, height: 46, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving…' : 'Save Profile'))),
  ]));

  Future<void> _showEditDetails() async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.viewInsetsOf(context).bottom + 24), child: _profileEditCard()));
  }

  Future<void> _showSecurityInfo() async {
    await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Account & security'), content: const Text('Your email address is your sign-in identity. Role and flock permissions are managed separately by the farm administrator.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard, bool readOnly = false}) => TextField(controller: controller, keyboardType: keyboard, readOnly: readOnly, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()));
}
