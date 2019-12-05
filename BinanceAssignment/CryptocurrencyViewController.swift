//
//  CryptocurrencyViewController.swift
//  BinanceAssignment
//
//  Created by Kao Ming-Hsiu on 2019/12/6.
//  Copyright © 2019 ObiCat. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class CryptocurrencyViewController: UIViewController {
    
    private let disposeBag = DisposeBag()
    
    var symbol: String!
    var tabVC: UITabBarController!
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        (tabVC.viewControllers?[0] as? LocalOrderBookViewController)?.symbol = symbol
        (tabVC.viewControllers?[1] as? MarketHistoryViewController)?.symbol = symbol
        (tabVC.viewControllers?[2] as? InfoViewController)?.symbol = symbol        
        
        segmentedControl.rx.selectedSegmentIndex.subscribe(onNext: { [unowned self] (index) in
            self.tabVC.selectedIndex = index
        }).disposed(by: disposeBag)        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "tabBarController" {
            tabVC = (segue.destination as! UITabBarController)
        }
    }
}
