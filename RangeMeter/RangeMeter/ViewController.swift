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

class ViewController: UIViewController {
    
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        RxAlamofire.requestJSON(.get, "https://isoline.route.cit.api.here.com/routing/7.2/calculateisoline.json?app_id=7IQiOdNho9z1vWo9aECh&app_code=oQDeGdXmm4oQAwqlwnCouQ&mode=fastest;car&rangetype=time&start=geo!52.51578,13.37749&range=300&singlecomponent=true")
            .subscribe(onNext: { (r, json) in
                
            })
            .disposed(by: disposeBag)
    }
    
}
