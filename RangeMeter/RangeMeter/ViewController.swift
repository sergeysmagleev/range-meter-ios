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
    @IBOutlet weak var batteryView: BatteryView!
    
    private let disposeBag = DisposeBag()
    private let locationManager = CLLocationManager()
    private let locationUpdates = PublishSubject<CLLocationCoordinate2D>()
    private let batteryLife = Observable<Int>
        .interval(5.0, scheduler: MainScheduler.instance)
        .scan(100.0) { (previousCharge, _) -> Double in
            let value = previousCharge - 5.0
            return value > 0 ? value : 0
    }.share()
    
    private var subscribed = false
    private var currentOverlay: MKOverlay?
    
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
            }.withLatestFrom(batteryLife, resultSelector: { (locationString, batteryLife) in
                return (locationString, batteryLife)
            })
            .flatMap { (locationString, batteryLife) -> Observable<(HTTPURLResponse, Any)> in
                let batteryString = Int(300 * batteryLife / 100)
                return RxAlamofire.requestJSON(.get, "https://isoline.route.cit.api.here.com/routing/7.2/calculateisoline.json?app_id=7IQiOdNho9z1vWo9aECh&app_code=oQDeGdXmm4oQAwqlwnCouQ&mode=fastest;car&rangetype=time&start=geo!\(locationString)&range=\(batteryString)&singlecomponent=true")
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
        batteryLife.subscribe(onNext: { [unowned self] (batteryLife) in
            self.batteryView.changeBatteryLife(batteryLife)
        }).disposed(by: disposeBag)
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
