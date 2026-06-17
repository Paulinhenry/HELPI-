import Flutter
import UIKit
import GoogleMaps // Google Maps SDK para iOS

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Injetar a API Key do Google Maps antes de tudo
    GMSServices.provideAPIKey("AIzaSyC-QhhU8DO0mkkuzx_MuSPz-Z4nwJtF37E")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
