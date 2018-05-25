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

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    private let disposeBag = DisposeBag()
    private let locationManager = CLLocationManager()
    private let locationUpdates = PublishSubject<CLLocationCoordinate2D>()
    private var subscribed = false
    private var currentOverlay: MKOverlay?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    private func subscribeToNetworking() {
        if subscribed {
            return
        }
        subscribed = true
        Observable<Int>
            .interval(5.0, scheduler: MainScheduler.instance)
            .withLatestFrom(locationUpdates)
            .debug()
            .map { location -> String in
                return "\(location.latitude),\(location.longitude)"
            }.flatMap { locationString -> Observable<(HTTPURLResponse, Any)> in
                return RxAlamofire.requestJSON(.get, "https://isoline.route.cit.api.here.com/routing/7.2/calculateisoline.json?app_id=7IQiOdNho9z1vWo9aECh&app_code=oQDeGdXmm4oQAwqlwnCouQ&mode=fastest;car&rangetype=time&start=geo!\(locationString)&range=300&singlecomponent=true")
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
            }
            .map { coordinates -> MKPolygon in
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
            renderer.strokeColor = UIColor.orange
            renderer.lineWidth = 3
            return renderer
            
        } else if overlay is MKPolygon {
            let renderer = MKPolygonRenderer(polygon: overlay as! MKPolygon)
            renderer.fillColor = UIColor.black.withAlphaComponent(0.5)
            renderer.strokeColor = UIColor.orange
            renderer.lineWidth = 2
            return renderer
        }
        
        return MKOverlayRenderer()
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
        let viewRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 5000, 5000)
        mapView.setRegion(viewRegion, animated: false)
    }
    
}
