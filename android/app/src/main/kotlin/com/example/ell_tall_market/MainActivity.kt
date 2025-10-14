package com.example.ell_tall_market

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "auth_deep_link"
    private lateinit var methodChannel: MethodChannel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // إعداد Method Channel للتواصل مع Flutter
        methodChannel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
        
        // التعامل مع Intent الأولي
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_VIEW) {
            val data: Uri? = intent.data
            data?.let { uri ->
                val url = uri.toString()
                println("📱 Android: Deep Link مستقبل: $url")
                
                // التحقق من أن الرابط خاص بالمصادقة
                if (isAuthDeepLink(url)) {
                    // إرسال الرابط إلى Flutter
                    methodChannel.invokeMethod("handleDeepLink", url)
                } else {
                    println("⚠️ Android: رابط غير متعرف عليه: $url")
                }
            }
        }
    }

    private fun isAuthDeepLink(url: String): Boolean {
        return try {
            val uri = Uri.parse(url)
            uri.scheme == "elltallmarket" && 
            uri.host == "auth" && 
            uri.path == "/callback"
        } catch (e: Exception) {
            false
        }
    }
}
