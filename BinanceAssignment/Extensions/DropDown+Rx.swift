//
//  DropDown+Rx.swift
//  BinanceAssignment
//
//  Created by Kao Ming-Hsiu on 2019/12/5.
//  Copyright © 2019 ObiCat. All rights reserved.
//

import RxSwift
import RxCocoa
import DropDown

extension Reactive where Base: DropDown {
    var selectionAction: Observable<(Int, String)> {
        return Observable.create({ (observer) -> Disposable in
            self.base.selectionAction = { index, item in
                observer.onNext((index, item))
            }
            return Disposables.create()
        })
    }
}
