//
//  Isoline.swift
//  RangeMeter
//
//  Created by Sergey Smagleev on 25.05.18.
//  Copyright © 2018 Sergey Smagleev. All rights reserved.
//

import ObjectMapper

class Isoline: Mappable {
    
    private(set) var range: Int?
    private(set) var component: [Component] = []
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        range <- map["range"]
        component <- map["component"]
    }
    
}
