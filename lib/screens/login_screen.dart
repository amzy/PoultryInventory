import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firebase = FirebaseService();
  final _imagePicker = ImagePicker();

  bool _isLogin = true;
  bool _isOwner = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;
  String? _avatarBase64;

  static const _primaryGreen = Color(0xFF087A4F);
  static const _softBackground = Color(0xFFF1F8F5);
  static const _textDark = Color(0xFF162126);
  static const _textMuted = Color(0xFF68747A);

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(bool login) {
    if (_loading) return;
    setState(() {
      _isLogin = login;
      _error = null;
      if (login) {
        _nameController.clear();
        _mobileController.clear();
        _confirmPasswordController.clear();
        _avatarBase64 = null;
        _isOwner = true;
      }
    });
  }

  Future<void> _pickAvatar() async {
    if (_loading) return;
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 700 * 1024) {
        setState(() => _error = 'Please choose a smaller profile photo.');
        return;
      }
      setState(() => _avatarBase64 = base64Encode(bytes));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to select the profile photo.');
      }
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await _firebase.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await _firebase.createAccount(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
          mobileNumber: _mobileController.text.trim(),
          role: _isOwner ? 'admin' : 'member',
          avatarBase64: _avatarBase64,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(e));
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? 'Unable to create your account.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _isLogin
            ? 'Unable to sign in. Please try again.'
            : 'Unable to create your account. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _firebase.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'sign-in-cancelled' || e.code == 'popup-closed-by-user') {
        setState(() => _error = 'Google sign-in was cancelled.');
      } else {
        setState(() => _error = _friendlyAuthError(e));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to sign in with Google. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _firebase.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 8 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'popup-blocked':
        return 'The Google sign-in popup was blocked. Please allow popups and try again.';
      case 'missing-google-id-token':
        return 'Google sign-in did not return a valid authentication token.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F5F0), Color(0xFFF7FBF9), Color(0xFFDFF2E9)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 35,
                        spreadRadius: 2,
                        offset: Offset(0, 18),
                        color: Color(0x24075C43),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeroBanner(),
                          const SizedBox(height: 26),
                          Text(
                            'Poultry Inventory',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 34,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isLogin
                                ? 'Sign in to manage your farm'
                                : 'Create your secure farm account',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 18,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 30),
                          if (!_isLogin) ...[
                            _buildAvatarPicker(),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _nameController,
                              hintText: 'Full name',
                              prefixIcon: Icons.person_outline_rounded,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              validator: (value) {
                                if ((value ?? '').trim().length < 2) {
                                  return 'Enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _mobileController,
                              hintText: 'Mobile number',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.telephoneNumber],
                              validator: (value) {
                                final mobile = (value ?? '').trim();
                                final digits = mobile.replaceAll(RegExp(r'[^0-9]'), '');
                                if (digits.length < 8 || digits.length > 15) {
                                  return 'Enter a valid mobile number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            _buildAccountTypePicker(),
                            const SizedBox(height: 14),
                          ],
                          _buildTextField(
                            controller: _emailController,
                            hintText: 'Email',
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return 'Enter your email';
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _passwordController,
                            hintText: 'Password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: _isLogin ? (_) => _submit() : null,
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                            validator: (value) {
                              if ((value ?? '').length < 8) return 'Minimum 8 characters';
                              return null;
                            },
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _confirmPasswordController,
                              hintText: 'Confirm password',
                              prefixIcon: Icons.lock_reset_outlined,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              onFieldSubmitted: (_) => _submit(),
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                              validator: (value) {
                                if (value != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                          ],
                          if (_isLogin) ...[
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loading ? null : _forgotPassword,
                                style: TextButton.styleFrom(
                                  foregroundColor: _primaryGreen,
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                ),
                                child: const Text('Forgot password?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ] else
                            const SizedBox(height: 18),
                          if (_error != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF2F1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF4C7C3)),
                              ),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Color(0xFFB42318), fontSize: 13),
                              ),
                            ),
                          ],
                          SizedBox(
                            height: 58,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: _primaryGreen,
                                disabledBackgroundColor: _primaryGreen.withValues(alpha: 0.55),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              child: _loading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(_isLogin ? 'Sign In' : 'Create Account', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.arrow_forward_rounded, size: 23),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (_isLogin) ...[
                            _buildOrDivider(),
                            const SizedBox(height: 22),
                            SizedBox(
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _signInWithGoogle,
                                icon: const _GoogleMark(),
                                label: const Text('Continue with Google', style: TextStyle(color: _textDark, fontSize: 16, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _textDark,
                                  side: const BorderSide(color: Color(0xFFD9E0E1), width: 1.3),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(_isLogin ? "Don't have an account?" : 'Already have an account?', style: const TextStyle(color: _textMuted, fontSize: 15)),
                              TextButton(
                                onPressed: _loading ? null : () => _switchMode(!_isLogin),
                                style: TextButton.styleFrom(
                                  foregroundColor: _primaryGreen,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(_isLogin ? 'Create a new account' : 'Sign in', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_user_outlined, size: 19, color: _primaryGreen),
                              SizedBox(width: 9),
                              Flexible(
                                child: Text(
                                  'Your farm data is private to your account.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _textMuted, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    final hasAvatar = _avatarBase64 != null;
    return Column(
      children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: const Color(0xFFE8F5F0),
                backgroundImage: hasAvatar ? MemoryImage(base64Decode(_avatarBase64!)) : null,
                child: hasAvatar ? null : const Icon(Icons.person_outline_rounded, size: 42, color: _primaryGreen),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: _primaryGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: _loading ? null : _pickAvatar, child: Text(hasAvatar ? 'Change profile photo' : 'Add profile photo (optional)')),
      ],
    );
  }

  Widget _buildAccountTypePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Account type', style: TextStyle(fontWeight: FontWeight.w700, color: _textDark)),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(child: _accountCard(isOwner: true, icon: Icons.home_work_outlined, title: 'Farm owner', subtitle: 'Admin access')),
            const SizedBox(width: 10),
            Expanded(child: _accountCard(isOwner: false, icon: Icons.groups_outlined, title: 'Farm member', subtitle: 'Join an invited farm')),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _isOwner
              ? 'Owners can create and manage flocks, members and farm settings.'
              : 'Members need an invitation sent to this email by a farm owner.',
          style: const TextStyle(color: _textMuted, fontSize: 12.5, height: 1.35),
        ),
      ],
    );
  }

  Widget _accountCard({required bool isOwner, required IconData icon, required String title, required String subtitle}) {
    final selected = _isOwner == isOwner;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _loading ? null : () => setState(() => _isOwner = isOwner),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5F0) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _primaryGreen : const Color(0xFFD9E0E1), width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _primaryGreen : _textMuted, size: 24),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _textMuted)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: _primaryGreen, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(fontSize: 17, color: _textDark),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: _textMuted, fontSize: 17),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF455157)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF9FBFA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD9E0E1), width: 1.2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD9E0E1), width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primaryGreen, width: 1.7)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD92D20), width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD92D20), width: 1.7)),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAF7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF0F3F2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFEAF6EF)],
              ),
            ),
          ),
          Image.asset('assets/app_icons/app_logo.png', fit: BoxFit.cover, alignment: const Alignment(0.02, -0.18)),
          Positioned(
            left: 0,
            right: 0,
            bottom: -1,
            height: 34,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.96)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFD9E0E1))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Text('OR', style: TextStyle(color: _textMuted, fontWeight: FontWeight.w600))),
        const Expanded(child: Divider(color: Color(0xFFD9E0E1))),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.39;
    final stroke = size.shortestSide * 0.17;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Multicolor Google "G" mark, drawn locally so it works on every platform
    // without relying on a remote image or a text-font approximation.
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.12, 1.58, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.46, 1.05, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.51, 0.92, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.43, 2.17, false, paint);

    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTRB(size.width * 0.50, size.height * 0.43, size.width * 0.96, size.height * 0.59), barPaint);
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}
