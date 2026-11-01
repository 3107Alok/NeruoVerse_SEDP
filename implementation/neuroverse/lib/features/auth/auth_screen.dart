import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../onboarding/splash_screen.dart'; // To route back to splash to check profile

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _submitEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (!_isLogin && password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        UserCredential cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Ensure we have latest emailVerified status from Firebase server
        try {
          await cred.user?.reload();
        } catch (_) {}

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && !currentUser.emailVerified) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please verify your email before logging in. Check your inbox!')),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      } else {
        UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        await cred.user?.sendEmailVerification();
        await FirebaseAuth.instance.signOut();
        
        if (mounted) {
          setState(() {
            _isLogin = true; // Switch back to login
            _passwordController.clear();
            _confirmPasswordController.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! A verification link has been sent to your email. Please verify to sign in.'),
              duration: Duration(seconds: 6),
            ),
          );
        }
        setState(() => _isLoading = false);
        return; // Don't proceed to splash screen, wait for verification
      }
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Authentication failed. Please try again.';
        if (e.code == 'network-request-failed') {
          errorMessage = 'No internet connection. Please check your network and try again.';
        } else if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          errorMessage = 'Invalid email or password.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Wrong password provided.';
        } else if (e.code == 'too-many-requests') {
          errorMessage = 'Too many attempts. Please try again later. (Rate limited)';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'The account already exists for that email.';
        }
        _showErrorDialog('Login Failed', errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error', 'An unexpected error occurred. Please try again later.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn();
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Google Sign-In failed.';
        if (e.code == 'network-request-failed') {
          errorMessage = 'No internet connection. Please check your network and try again.';
        }
        _showErrorDialog('Connection Error', errorMessage);
      }
    } catch (e) {
      if (mounted) {
        // Catch platform exceptions (like user canceling halfway through a webview or no internet for the google modal)
        if (e.toString().contains('network_error') || e.toString().contains('SocketException')) {
          _showErrorDialog('No Internet', 'Please check your internet connection to sign in with Google.');
        } else if (!e.toString().contains('sign_in_canceled')) {
           _showErrorDialog('Google Sign-In Failed', 'An error occurred during Google Sign-In. Please try again.');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first to reset password.')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset link sent to your email!')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'network-request-failed') {
          _showErrorDialog('No Internet', 'No internet connection. Please check your network and try again.');
        } else {
          _showErrorDialog('Error', e.message ?? 'Failed to reset password.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error', 'An unexpected error occurred.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFBF9F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 14.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  // Glowing Emerald Brain App Icon (Unchanged dimensions & asset)
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00796B).withValues(alpha: 0.22),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/app_icon.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00796B).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.psychology_rounded, size: 52, color: Color(0xFF00796B)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'NEUROVERSE',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: const Color(0xFF00796B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Care Together. Grow Together.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: isDark ? Colors.white60 : const Color(0xFF4A6B63),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : const Color(0xFF1B3B36),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLogin
                        ? 'Sign in to continue your cognitive wellness journey.'
                        : 'Join NeuroVerse and nurture your mind every day.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : const Color(0xFF4A6B63),
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 14),

                  // Segmented Mode Switcher (Sign In vs Create Account)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C2825) : const Color(0xFFE8F5ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2B3E39) : const Color(0xFFC8E6C9),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (!_isLogin) setState(() => _isLogin = true);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: _isLogin
                                    ? (isDark ? const Color(0xFF263632) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _isLogin && !isDark
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: _isLogin ? FontWeight.bold : FontWeight.w500,
                                    color: _isLogin
                                        ? const Color(0xFF00796B)
                                        : (isDark ? Colors.white60 : const Color(0xFF5A7B73)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (_isLogin) setState(() => _isLogin = false);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: !_isLogin
                                    ? (isDark ? const Color(0xFF263632) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: !_isLogin && !isDark
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: !_isLogin ? FontWeight.bold : FontWeight.w500,
                                    color: !_isLogin
                                        ? const Color(0xFF00796B)
                                        : (isDark ? Colors.white60 : const Color(0xFF5A7B73)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Elevated Core Form Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B2422) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2B3A36) : const Color(0xFFE2ECE8),
                        width: 1.2,
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF00796B).withValues(alpha: 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email Field
                        TextField(
                          controller: _emailController,
                          style: TextStyle(
                            fontSize: 15.5,
                            color: isDark ? Colors.white : const Color(0xFF1E2829),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF4A6B63),
                              fontSize: 14.5,
                            ),
                            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF00796B), size: 22),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF141C1A) : const Color(0xFFF7FAF9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white12 : const Color(0xFFD1E0DC),
                                width: 1.2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white12 : const Color(0xFFD1E0DC),
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFF00796B), width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),

                        // Password Field
                        TextField(
                          controller: _passwordController,
                          style: TextStyle(
                            fontSize: 15.5,
                            color: isDark ? Colors.white : const Color(0xFF1E2829),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF4A6B63),
                              fontSize: 14.5,
                            ),
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00796B), size: 22),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF00796B),
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF141C1A) : const Color(0xFFF7FAF9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white12 : const Color(0xFFD1E0DC),
                                width: 1.2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white12 : const Color(0xFFD1E0DC),
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFF00796B), width: 2),
                            ),
                          ),
                          obscureText: _obscurePassword,
                        ),
                        
                        if (!_isLogin) ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: _confirmPasswordController,
                            style: TextStyle(
                              fontSize: 15.5,
                              color: isDark ? Colors.white : const Color(0xFF1E2829),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              labelStyle: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF4A6B63),
                                fontSize: 14.5,
                              ),
                              prefixIcon: const Icon(Icons.lock_reset, color: Color(0xFF00796B), size: 22),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                  color: const Color(0xFF00796B),
                                  size: 22,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF141C1A) : const Color(0xFFF7FAF9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.white12 : const Color(0xFFD1E0DC),
                                  width: 1.2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.white12 : const Color(0xFFD1E0DC),
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFF00796B), width: 2),
                              ),
                            ),
                            obscureText: _obscureConfirmPassword,
                          ),
                        ],
                        
                        if (_isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF00796B),
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 18),
                        
                        const SizedBox(height: 4),

                        // Primary Action Button (Sign In / Create Account)
                        SizedBox(
                          height: 50,
                          child: _isLoading 
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Color(0xFF00796B), strokeWidth: 2.8),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _submitEmailAuth,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00796B),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isLogin ? Icons.login_rounded : Icons.person_add_rounded,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isLogin ? 'Sign In' : 'Create Account',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ),

                        const SizedBox(height: 6),

                        // Mode Switch Text Link right under primary button
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() => _isLogin = !_isLogin),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF00796B),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            child: Text(
                              _isLogin ? 'Don\'t have an account? Sign Up' : 'Already have an account? Sign In',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // "OR" Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : const Color(0xFF78909C),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
                    ],
                  ),

                  const SizedBox(height: 12),
                  
                  // Google Sign-In Button with Authentic Vector Emblem
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1B2422) : Colors.white,
                        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF2B3A36) : const Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: isDark ? 0 : 1,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _GoogleGLogo(size: 19),
                          SizedBox(width: 10),
                          Text(
                            'Sign in with Google',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clean, official-style multi-colored Google "G" vector emblem
class _GoogleGLogo extends StatelessWidget {
  final double size;
  const _GoogleGLogo({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleGLogoPainter(),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. Red Top Arc (Official Google coordinates)
    final redPath = Path()
      ..moveTo(12, 4.75)
      ..cubicTo(13.77, 4.75, 15.35, 5.36, 16.6, 6.55)
      ..lineTo(20.02, 3.13)
      ..cubicTo(17.95, 1.19, 15.24, 0, 12, 0)
      ..cubicTo(7.33, 0, 3.26, 2.64, 1.25, 6.58)
      ..lineTo(5.28, 9.73)
      ..cubicTo(6.23, 6.9, 8.88, 4.75, 12, 4.75)
      ..close();
    canvas.drawPath(redPath, Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill);

    // 2. Yellow Left Arc
    final yellowPath = Path()
      ..moveTo(5.28, 14.27)
      ..cubicTo(5.03, 13.55, 4.9, 12.78, 4.9, 12)
      ..cubicTo(4.9, 11.22, 5.03, 10.45, 5.28, 9.73)
      ..lineTo(1.25, 6.58)
      ..cubicTo(0.45, 8.18, 0, 9.99, 0, 12)
      ..cubicTo(0, 14.01, 0.45, 15.82, 1.25, 17.42)
      ..lineTo(5.28, 14.27)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill);

    // 3. Green Bottom Arc
    final greenPath = Path()
      ..moveTo(12, 24)
      ..cubicTo(15.24, 24, 17.95, 22.92, 19.93, 21.09)
      ..lineTo(16.05, 18.04)
      ..cubicTo(14.97, 18.76, 13.6, 19.2, 12, 19.2)
      ..cubicTo(8.88, 19.2, 6.23, 17.05, 5.28, 14.22)
      ..lineTo(1.25, 17.37)
      ..cubicTo(3.26, 21.36, 7.33, 24, 12, 24)
      ..close();
    canvas.drawPath(greenPath, Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill);

    // 4. Blue Right & Crossbar
    final bluePath = Path()
      ..moveTo(23.75, 12.27)
      ..cubicTo(23.75, 11.57, 23.69, 10.87, 23.56, 10.2)
      ..lineTo(12, 10.2)
      ..lineTo(12, 14.71)
      ..lineTo(18.6, 14.71)
      ..cubicTo(18.31, 16.23, 17.46, 17.53, 16.2, 18.39)
      ..lineTo(20.08, 21.44)
      ..cubicTo(22.35, 19.35, 23.75, 16.27, 23.75, 12.27)
      ..close();
    canvas.drawPath(bluePath, Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
