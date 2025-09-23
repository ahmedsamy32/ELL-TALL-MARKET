import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class FacebookAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<User?> signInWithFacebook() async {
    try {
      // Trigger the Facebook Authentication flow
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        // Get the access token
        final AccessToken? accessToken = result.accessToken;

        // Create a credential from the access token
        final credential = FacebookAuthProvider.credential(
          accessToken!.tokenString,
        );

        // Sign in to Firebase with the Facebook credential
        final UserCredential userCredential = await _firebaseAuth
            .signInWithCredential(credential);

        return userCredential.user;
      } else {
        print('Facebook login failed: ${result.status}');
        return null;
      }
    } catch (e) {
      print('Error signing in with Facebook: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await FacebookAuth.instance.logOut();
  }
}
