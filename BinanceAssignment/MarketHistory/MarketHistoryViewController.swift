//
//  MarketHistoryViewController.swift
//  BinanceAssignment
//
//  Created by Kao Ming-Hsiu on 2019/12/5.
//  Copyright © 2019 ObiCat. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Moya
import Starscream

class MarketHistoryViewController: UIViewController {
    var symbol: String!
    
    let disposeBag = DisposeBag()
    let backgroundScheduler = ConcurrentDispatchQueueScheduler(qos: .default)
    
    let provider = MoyaProvider<WebService>()
    
    lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
    
    lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        return dateFormatter
    }()
    
    lazy var websocket: WebSocket = {
        guard
            let url = URL(string: "wss://stream.binance.com:9443/ws/\(self.symbol.lowercased())@aggTrade") else {
                fatalError("Invalid URL format.")
        }
        return WebSocket(url: url)
    }()
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        websocket.connect()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        websocket.disconnect()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let webServiceExchangeInfo = provider.rx.request(.exchangeInfo(symbol: symbol))
            .observeOn(backgroundScheduler)
            .map([ExchangeInfo].self, atKeyPath: "data", using: decoder)
            .asObservable()
            .flatMap { Observable.from(optional: $0.first) }
            .retry()
            .publish()
        
        let webServiceTrades = rx.methodInvoked(#selector(viewWillAppear(_:)))
            .flatMap { [unowned self] _ in
                self.provider.rx.request(.aggTrades(symbol: self.symbol, limit: 80))
            }
            .observeOn(backgroundScheduler)
            .map([AggTrade].self, using: decoder)
            .retry()
            .publish()
        
        let socketTrades = websocket.rx.didReceiveMessage
            .map { message in
                return try self.decoder.decode(AggTrade.self, from: message.data(using: .utf8) ?? Data())
            }
            .publish()
        
        // collect & process histories from api + socket.
        let data = webServiceTrades
            .flatMap { t -> Observable<[AggTrade]> in
                var trades = t
                var socketTradesToScan = socketTrades
                    .takeUntil(webServiceTrades)
                    .asObservable()
                if let latestTrade = trades.popLast() {
                    socketTradesToScan = socketTradesToScan.startWith(latestTrade)
                }
                return socketTradesToScan.scan(into: trades, accumulator: { $0.append($1) })
            }
            .share(replay: 1, scope: .forever)
        
        // prepare data for displaying.
        Observable.combineLatest(
            // price level formatter
            webServiceExchangeInfo.map { info -> NumberFormatter in
                var digits = info.minTickSize.count-2
                if digits < 0 { digits = 0 }
                return NumberFormatter.decimalFormatter(fractionDigits: digits)
            },
            // quantity formatter
            webServiceExchangeInfo.map { info -> NumberFormatter in
                var digits = info.minTradeAmount.count-2
                if digits < 0 { digits = 0 }
                return NumberFormatter.decimalFormatter(fractionDigits: digits)
            },
            data
        )
            .map { formatter, quantityFormatter, data in
                data.lazy.map { ($0, formatter, quantityFormatter)}.reversed()
            }
            .asDriver(onErrorJustReturn: [])
            // binding to tableView.
            .drive(tableView.rx.items(cellIdentifier: "MarketHistoryCell", cellType: MarketHistoryCell.self)) { [unowned self] row, args, cell in
                let (aggTrade, formatter, quantityFormatter) = args
                cell.priceLabel.text = formatter.string(from: NSNumber(value: aggTrade.price))
                cell.priceLabel.textColor = aggTrade.isTheMarketMaker ? .red : .green
                cell.quantityLabel.text = quantityFormatter.string(from: NSNumber(value: aggTrade.quantity))
                cell.timeLabel.text = self.dateFormatter.string(from: aggTrade.tradeTime)
            }
            .disposed(by: disposeBag)
        
        // subscribe api, webSocket
        webServiceExchangeInfo.connect().disposed(by: disposeBag)
        webServiceTrades.connect().disposed(by: disposeBag)
        socketTrades.connect().disposed(by: disposeBag)
    }
    
}
