import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Register existing plugins first
        GeneratedPluginRegistrant.register(with: self)
        
        // Register AudioClassificationPlugin
        if let registrar = self.registrar(forPlugin: "AudioClassificationPlugin") {
            AudioClassificationPlugin.register(with: registrar)
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
