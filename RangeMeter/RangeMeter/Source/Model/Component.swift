//
//  Component.swift
//  RangeMeter
//
//  Created by Sergey Smagleev on 25.05.18.
//  Copyright © 2018 Sergey Smagleev. All rights reserved.
//

import ObjectMapper

class Component: Mappable {
    
    private(set) var id: Int?
    private(set) var shape: [Coordinate] = []
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        id <- map["id"]
        shape <- (map["shape"], CoordinateTransform())
    }
    
}

