//
//  NumberFormatter+Decimal.swift
//  BinanceAssignment
//
//  Created by Kao Ming-Hsiu on 2019/12/6.
//  Copyright © 2019 ObiCat. All rights reserved.
//

import Foundation

extension NumberFormatter {
    static func decimalFormatter(fractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter
    }        
}
