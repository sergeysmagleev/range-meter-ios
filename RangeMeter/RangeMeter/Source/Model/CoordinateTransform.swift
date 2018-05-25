//
//  ShapeTransform.swift
//  RangeMeter
//
//  Created by Sergey Smagleev on 25.05.18.
//  Copyright © 2018 Sergey Smagleev. All rights reserved.
//

import ObjectMapper

class CoordinateTransform: TransformType {
    
    func transformFromJSON(_ value: Any?) -> Coordinate? {
        guard let coordinateString = value as? String else {
            return nil
        }
        let coords = coordinateString.components(separatedBy: ",")
        guard coords.count == 2 else {
            return nil
        }
        if let lat = Double(coords[0]),
            let lng = Double(coords[1]) {
            return Coordinate(lat: lat, lng: lng)
        }
        return nil
    }
    
    func transformToJSON(_ value: Coordinate?) -> String? {
        guard let coordinate = value else {
            return nil
        }
        return "\(coordinate.lat),\(coordinate.lng)"
    }
    
}

