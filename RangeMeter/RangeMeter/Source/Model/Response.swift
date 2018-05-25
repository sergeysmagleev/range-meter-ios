//
//  Response.swift
//  RangeMeter
//
//  Created by Sergey Smagleev on 25.05.18.
//  Copyright © 2018 Sergey Smagleev. All rights reserved.
//

import ObjectMapper

class Response: Mappable {
    
    private(set) var isoline: [Isoline] = []
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        isoline <- map["isoline"]
    }
    
}
