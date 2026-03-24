import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCatuTexUTv_Ibm1pZBAdAdguhvRQXWwQE")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MoMoPlusMaps") else { return }
    let channel = FlutterMethodChannel(name: "momoplus/maps", binaryMessenger: registrar.messenger())

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "openStreetView":
        self?.openStreetView(call: call, result: result)
      case "openDirections":
        self?.openDirections(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func openStreetView(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let latitude = args["latitude"] as? Double,
          let longitude = args["longitude"] as? Double else {
      result(FlutterError(code: "invalid_args", message: "Latitude and longitude are required.", details: nil))
      return
    }

    let title = args["title"] as? String ?? ""
    let bearing = args["bearing"] as? Double ?? 0

    DispatchQueue.main.async { [weak self] in
      let streetVC = StreetViewController()
      streetVC.latitude = latitude
      streetVC.longitude = longitude
      streetVC.titleText = title
      streetVC.initialBearing = Float(bearing)
      streetVC.modalPresentationStyle = .fullScreen

      self?.topViewController()?.present(streetVC, animated: true)
    }
    result(nil)
  }

  private func openDirections(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let latitude = args["latitude"] as? Double,
          let longitude = args["longitude"] as? Double else {
      result(FlutterError(code: "invalid_args", message: "Latitude and longitude are required.", details: nil))
      return
    }

    let mapsUrl = URL(string: "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving")
    let webUrl = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(latitude),\(longitude)&travelmode=driving")!

    if let mapsUrl = mapsUrl, UIApplication.shared.canOpenURL(mapsUrl) {
      UIApplication.shared.open(mapsUrl)
    } else {
      UIApplication.shared.open(webUrl)
    }
    result(nil)
  }

  private func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first
    let root = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    var top = root
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
