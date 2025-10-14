import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "auth_deep_link"
  private var methodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // إعداد Method Channel للتواصل مع Flutter
    let controller = window?.rootViewController as! FlutterViewController
    methodChannel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // التعامل مع Deep Links في iOS
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    print("📱 iOS: Deep Link مستقبل: \(url.absoluteString)")
    
    if isAuthDeepLink(url: url) {
      // إرسال الرابط إلى Flutter
      methodChannel?.invokeMethod("handleDeepLink", arguments: url.absoluteString)
      return true
    } else {
      print("⚠️ iOS: رابط غير متعرف عليه: \(url.absoluteString)")
      return super.application(app, open: url, options: options)
    }
  }
  
  // التحقق من أن الرابط خاص بالمصادقة
  private func isAuthDeepLink(url: URL) -> Bool {
    return url.scheme == "elltallmarket" &&
           url.host == "auth" &&
           url.path == "/callback"
  }
}
