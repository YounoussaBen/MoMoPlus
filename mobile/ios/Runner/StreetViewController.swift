import UIKit
import GoogleMaps

class StreetViewController: UIViewController {
    var latitude: Double = 0
    var longitude: Double = 0
    var initialBearing: Float = 0
    var titleText: String = "Street View"

    private var panoramaView: GMSPanoramaView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Panorama view
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        panoramaView = GMSPanoramaView(frame: view.bounds)
        panoramaView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        panoramaView.moveNearCoordinate(coordinate, radius: 50)
        panoramaView.camera = GMSPanoramaCamera(
            heading: CLLocationDirection(initialBearing),
            pitch: 0,
            zoom: 0.8
        )
        view.addSubview(panoramaView)

        // Top bar overlay
        let topBar = UIView()
        topBar.backgroundColor = UIColor(red: 16/255, green: 24/255, blue: 32/255, alpha: 0.8)
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.tintColor = .white
        let closeImage = UIImage(systemName: "xmark")
        closeButton.setImage(closeImage, for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        // Title label
        let titleLabel = UILabel()
        titleLabel.text = titleText.isEmpty ? "Street View" : titleText
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle label
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Pan, zoom, and move around the area"
        subtitleLabel.textColor = UIColor(red: 221/255, green: 231/255, blue: 236/255, alpha: 1)
        subtitleLabel.font = UIFont.systemFont(ofSize: 13)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        topBar.addSubview(closeButton)
        topBar.addSubview(textStack)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 12),
            closeButton.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -18),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            textStack.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            topBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 58),
        ])
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
