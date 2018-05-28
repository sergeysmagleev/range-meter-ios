//
//  ViewController.swift
//  RangeMeter
//
//  Created by Sergey Smagleev on 25.05.18.
//  Copyright © 2018 Sergey Smagleev. All rights reserved.
//

import RxAlamofire
import RxSwift
import UIKit
import ObjectMapper
import MapKit
import CoreLocation
import CoreGraphics

let hereAPIAppId = ""
let hereAPIAppCode = ""

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var batteryView: BatteryView!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var weatherIcon: UIImageView!
    
    private let disposeBag = DisposeBag()
    private let locationManager = CLLocationManager()
    private let locationUpdates = PublishSubject<CLLocationCoordinate2D>()
    private let batteryLife = Observable<Int>
        .interval(5.0, scheduler: MainScheduler.instance)
        .scan(100.0) { (previousCharge, _) -> Double in
            let value = previousCharge - 5.0
            return value > 0 ? value : 0
    }.share()
    
    private let hardcodedPinLocations = [
        CLLocationCoordinate2D(latitude: 37.7782793, longitude: -122.41496819999998),
        CLLocationCoordinate2D(latitude: 37.709593866171616, longitude: -122.45960015800779),
        CLLocationCoordinate2D(latitude: 37.61936453669866, longitude: -122.41668481376945),
        CLLocationCoordinate2D(latitude: 37.553253695187344, longitude: -122.3147179558593),
        CLLocationCoordinate2D(latitude: 37.48790142116992, longitude: -122.27180261162101),
        CLLocationCoordinate2D(latitude: 37.438031859296984, longitude: -122.13501972313577),
        CLLocationCoordinate2D(latitude: 37.366030298687946, longitude: -122.07905811424905),
        CLLocationCoordinate2D(latitude: 37.33054956877157, longitude: -122.04129261131936),
        CLLocationCoordinate2D(latitude: 37.35620654453343, longitude: -121.95031208153421),
        CLLocationCoordinate2D(latitude: 37.2912282677701, longitude: -121.88630908655603),
        
        CLLocationCoordinate2D(latitude: 48.86474096651445, longitude: 2.341976168271458),
        CLLocationCoordinate2D(latitude: 48.8513010249519, longitude: 2.3910713220800517),
        CLLocationCoordinate2D(latitude: 48.88430722089567, longitude: 2.368240358945286),
        CLLocationCoordinate2D(latitude: 48.851447954890155, longitude: 2.423171999570286),
        CLLocationCoordinate2D(latitude: 48.82975579853948, longitude: 2.349185946103489),
        CLLocationCoordinate2D(latitude: 48.84894114003227, longitude: 2.3028373743261454),
        CLLocationCoordinate2D(latitude: 48.84046833542856, longitude: 2.2781181360448954),
        CLLocationCoordinate2D(latitude: 48.85402413473328, longitude: 2.3320198084081767),
        CLLocationCoordinate2D(latitude: 48.87604448224109, longitude: 2.421970369931614),
        CLLocationCoordinate2D(latitude: 48.868253774651905, longitude: 2.364120485898411),
        CLLocationCoordinate2D(latitude: 48.82781294511909, longitude: 2.376480105039036),
        CLLocationCoordinate2D(latitude: 48.83854763376411, longitude: 2.4005126978124736),
        CLLocationCoordinate2D(latitude: 48.83018607431655, longitude: 2.3495292688573954),
        CLLocationCoordinate2D(latitude: 48.811650076775976, longitude: 2.3840332056249736)
    ]
    
    private var subscribed = false
    private var currentOverlay: MKOverlay?
    private var currentPins: [MKPointAnnotation] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse {
            locationManager.requestWhenInUseAuthorization()
        } else {
            subscribeToNetworking()
        }
        temperatureLabel.layer.shadowColor = UIColor.black.cgColor
        temperatureLabel.layer.shadowOffset = CGSize(width: 2, height: 2)
        temperatureLabel.layer.shadowRadius = 2
        temperatureLabel.layer.shadowOpacity = 1.0
        weatherIcon.layer.shadowColor = UIColor.black.cgColor
        weatherIcon.layer.shadowOffset = CGSize(width: 2, height: 2)
        weatherIcon.layer.shadowRadius = 2
        weatherIcon.layer.shadowOpacity = 1.0
    }
    
    private func subscribeToNetworking() {
        if subscribed {
            return
        }
        subscribed = true
        let response = Observable<Int>
            .interval(5.0, scheduler: MainScheduler.instance)
            .withLatestFrom(locationUpdates)
            .debug()
            .map { location -> String in
                return "\(location.latitude),\(location.longitude)"
            }.withLatestFrom(batteryLife, resultSelector: { (locationString, batteryLife) in
                return (locationString, batteryLife)
            })
            .flatMap { (arg) -> Observable<(HTTPURLResponse, Any)> in
                let (locationString, batteryLife) = arg
                return RxAlamofire.requestJSON(.get, "https://isoline.route.cit.api.here.com/routing/7.2/calculateisoline.json?app_id=\(hereAPIAppId)&app_code=\(hereAPIAppCode)&mode=fastest;car&rangetype=time&start=geo!\(locationString)&range=\(self.timeInSeconds(batteryLife: batteryLife))&singlecomponent=true")
            }.map { (arg) -> Response? in
                let (_, json) = arg
                let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
                guard let jsonString = String(data: jsonData, encoding: .utf8),
                    let response = Mapper<Response>().map(JSONString: jsonString) else {
                        return nil
                }
                return response
            }.flatMap { response -> Observable<Response> in
                if let response = response {
                    return .just(response)
                } else {
                    return .empty()
                }
            }.map { response -> [Coordinate] in
                return response.isoline.first?.component.first?.shape ?? []
            }.map { coordinates -> [CLLocationCoordinate2D] in
                return coordinates.map { coordinate in
                    return CLLocationCoordinate2D(latitude: coordinate.lat,
                                                  longitude: coordinate.lng)
                }
            }.share()
        
        response.map { coordinates -> CGPath in
            let path = CGMutablePath()
            guard let firstPoint = coordinates.first else {
                return path
            }
            path.move(to: CGPoint(x: firstPoint.latitude, y: firstPoint.longitude))
            coordinates.forEach { (coordinate) in
                path.addLine(to: CGPoint(x: coordinate.latitude, y: coordinate.longitude))
            }
            path.addLine(to: CGPoint(x: firstPoint.latitude, y: firstPoint.longitude))
            path.closeSubpath()
            return path
            }.map { [unowned self] path -> [CLLocationCoordinate2D] in
                return self.hardcodedPinLocations.map { coordinate -> (CLLocationCoordinate2D, CGPoint) in
                    return (coordinate, CGPoint(x: coordinate.latitude, y: coordinate.longitude))
                    }
                    .filter { (_, point) in
                        return path.contains(point)
                    }.map{ (coordinate, point) -> CLLocationCoordinate2D in
                        return coordinate
                }
            }.subscribe(onNext: { [unowned self] coordinates in
                let annotations = coordinates.map { coordinate -> MKPointAnnotation in
                    let view = MKPointAnnotation()
                    view.coordinate = coordinate
                    return view
                }
                self.mapView.addAnnotations(annotations)
                self.mapView.removeAnnotations(self.currentPins)
                self.currentPins = annotations
            }).disposed(by: disposeBag)
            
        response.map { coordinates -> MKPolygon in
            return MKPolygon(coordinates: coordinates, count: coordinates.count)
            }.debug()
            .subscribe(onNext: { [unowned self] polygon in
                if let overlay = self.currentOverlay {
                    self.mapView.remove(overlay)
                }
                self.mapView.add(polygon)
                self.currentOverlay = polygon
            })
            .disposed(by: disposeBag)
        batteryLife.subscribe(onNext: { [unowned self] (batteryLife) in
            self.batteryView.changeBatteryLife(batteryLife)
        }).disposed(by: disposeBag)
    }
    
    private func timeInSeconds(batteryLife: Double) -> Int {
        let kwh = 37.0
        let whm = 146.0
        let distance = (kwh / whm) * 1000
        let constantVelocity = 80.5
        let timeInHours = distance / constantVelocity
        let batteryLifeMultiple = batteryLife / 1000
        return Int(timeInHours * 3600 * batteryLifeMultiple)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKCircle {
            let renderer = MKCircleRenderer(overlay: overlay)
            renderer.fillColor = UIColor.black.withAlphaComponent(0.5)
            renderer.strokeColor = UIColor.blue
            renderer.lineWidth = 2
            return renderer
            
        } else if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = UIColor.blue
            renderer.lineWidth = 3
            return renderer
            
        } else if overlay is MKPolygon {
            let renderer = MKPolygonRenderer(polygon: overlay as! MKPolygon)
            renderer.fillColor = UIColor(red: 0.5, green: 0.55, blue: 0.6, alpha: 0.5)
            renderer.strokeColor = UIColor(red: 0.25, green: 0.2, blue: 0.4, alpha: 0.95)
            renderer.lineWidth = 1
            return renderer
        }
        
        return MKOverlayRenderer()
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if annotation is MKUserLocation {
            return nil
        }
        let reuseID = "lighning"
        if let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) {
            view.annotation = annotation
            return view
        }
        let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
        annotationView.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        let image = UIImage(named: "lightning-bolt-64")!
        let size = min(image.size.width, image.size.height)
        annotationView.image = image
        annotationView.contentMode = .scaleAspectFit
        annotationView.layer.cornerRadius = size / 2
        annotationView.layer.masksToBounds = true
        annotationView.annotation = annotation
        annotationView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return annotationView
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            subscribeToNetworking()
        default:
            print("authorization denied")
        }
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }
        locationUpdates.onNext(location.coordinate)
        let viewRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 10000, 10000)
        mapView.setRegion(viewRegion, animated: false)
    }
    
}
