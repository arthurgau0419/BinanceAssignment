//
//  InputSymbolViewController.swift
//  BinanceAssignment
//
//  Created by Kao Ming-Hsiu on 2019/12/6.
//  Copyright © 2019 ObiCat. All rights reserved.
//

import UIKit

class InputSymbolViewController: UIViewController {
    
    @IBOutlet weak var symbolTextField: UITextField!
    
    @IBAction func showSymbol(_ sender: UIButton) {
        guard let symbol = symbolTextField.text else { return }
        performSegue(withIdentifier: "showCryptocurrencyViewController", sender: symbol)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showCryptocurrencyViewController" {
            let vc = segue.destination as! CryptocurrencyViewController
            let symbol = (sender as? String)?.uppercased()
            vc.title = symbol
            vc.symbol = symbol
        }
    }
    
}
