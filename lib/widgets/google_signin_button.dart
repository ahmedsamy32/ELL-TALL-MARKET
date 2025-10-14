/// مثال على استخدام Google Sign-In مع Supabase
/// يمكن استخدام هذا الكود في شاشة تسجيل الدخول
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/google_signin_service.dart';

class GoogleSignInButton extends StatefulWidget {
  final VoidCallback? onSuccess;
  final Function(String)? onError;

  const GoogleSignInButton({Key? key, this.onSuccess, this.onError})
    : super(key: key);

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await GoogleSignInService.instance.signInWithGoogle();

      if (response != null && response.user != null) {
        // نجح تسجيل الدخول
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        }

        // عرض رسالة نجاح
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('أهلاً بك ${response.user!.email}!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // فشل تسجيل الدخول
        if (widget.onError != null) {
          widget.onError!('فشل في تسجيل الدخول مع Google');
        }
      }
    } catch (e) {
      // خطأ في تسجيل الدخول
      if (widget.onError != null) {
        widget.onError!('خطأ: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تسجيل الدخول: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Image.asset(
                'assets/icons/icons8-google-192.png',
                width: 24,
                height: 24,
              ),
        label: Text(
          _isLoading ? 'جارِ تسجيل الدخول...' : 'تسجيل الدخول مع Google',
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          side: const BorderSide(color: Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

/// مثال على كيفية استخدام الزر في صفحة تسجيل الدخول
class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'أهلاً بك في سوق التل',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // زر تسجيل الدخول مع Google
            GoogleSignInButton(
              onSuccess: () {
                // الانتقال للصفحة الرئيسية
                Navigator.pushReplacementNamed(context, '/home');
              },
              onError: (error) {
                // عرض خطأ إضافي إذا لزم الأمر
                print('خطأ في تسجيل الدخول: $error');
              },
            ),

            const SizedBox(height: 16),

            // معلومات إضافية
            const Text(
              'بتسجيل الدخول، أنت توافق على شروط الاستخدام',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// مثال على كيفية التحقق من حالة المصادقة
class AuthChecker extends StatelessWidget {
  const AuthChecker({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        if (session != null) {
          // المستخدم مسجل دخول
          return const HomePage(); // استبدل بصفحتك الرئيسية
        } else {
          // المستخدم غير مسجل دخول
          return const LoginPage();
        }
      },
    );
  }
}

// صفحة وهمية للمثال
class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userInfo = GoogleSignInService.instance.userDisplayInfo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الصفحة الرئيسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await GoogleSignInService.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (userInfo != null) ...[
              if (userInfo['avatar']?.isNotEmpty == true)
                CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(userInfo['avatar']),
                ),
              const SizedBox(height: 16),
              Text(
                'أهلاً بك ${userInfo['name']}',
                style: const TextStyle(fontSize: 24),
              ),
              Text(
                userInfo['email'],
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
