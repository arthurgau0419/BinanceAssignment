//
//  LocalOrderBookCell.swift
//  BinanceAssignment
//
//  Created by Kao Ming-Hsiu on 2019/12/4.
//  Copyright © 2019 ObiCat. All rights reserved.
//

import UIKit

class LocalOrderBookCell: UITableViewCell {
    
    @IBOutlet weak var bidQuantity: UILabel!
    @IBOutlet weak var bidPriceLevel: UILabel!
    @IBOutlet weak var bidColorView: UIView!
    @IBOutlet weak var bidPriceLevelConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var askQuantity: UILabel!
    @IBOutlet weak var askPriceLevel: UILabel!
    @IBOutlet weak var askColorView: UIView!
    @IBOutlet weak var askPriceLevelConstraint: NSLayoutConstraint!
    
}
