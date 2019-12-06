//
//  LocalOrderBookViewController.swift
//  BinanceAssignment
//
//  Created by Kao Ming-Hsiu on 2019/12/4.
//  Copyright © 2019 ObiCat. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Moya
import Starscream
import DropDown
import Reachability
import RxReachability

protocol CellModelType {
    var bidPriceLevel: Double? {get}
    var bidQuantity: Double? {get}
    var askPriceLevel: Double? {get}
    var askQuantity: Double? {get}
}

struct CellModel: CellModelType {
    let bidPriceLevel: Double?
    let bidQuantity: Double?
    let askPriceLevel: Double?
    let askQuantity: Double?
    
    init(bid: (Double, Double)?, ask: (Double, Double)?) {
        bidPriceLevel = bid?.0
        bidQuantity = bid?.1
        askPriceLevel = ask?.0
        askQuantity = ask?.1
    }
}

class LocalOrderBookViewController: UIViewController {
    var symbol: String!
    
    let disposeBag = DisposeBag()
    let backgroundScheduler = ConcurrentDispatchQueueScheduler(qos: .default)
    
    let provider = MoyaProvider<WebService>()
    
    lazy var reachability: Reachability = { Reachability()! }()
    
    lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
    
    lazy var websocket: WebSocket = {
        guard
            let url = URL(string: "wss://stream.binance.com:9443/ws/\(self.symbol.lowercased())@depth") else {
                fatalError("Invalid URL format.")
        }
        return WebSocket(url: url)
    }()
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var digitsDropDown: UIView!
    @IBOutlet weak var digitsDropDownLabel: UILabel!
    @IBOutlet weak var digitsDropDownGestureRecognizer: UITapGestureRecognizer!
    private let dropDown = DropDown()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        try? reachability.startNotifier()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reachability.stopNotifier()
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDropDown()
        
        reachability.rx.isConnected
            .subscribe(onNext: { [unowned self] _ in
                self.websocket.connect()
            })
            .disposed(by: disposeBag)

        reachability.rx.isDisconnected
            .subscribe(onNext: { [unowned self] _ in
                self.websocket.disconnect()
            })
            .disposed(by: disposeBag)
        
        let webServiceExchangeInfo = reachability.rx.isConnected
            .flatMap { [unowned self] _ in
                self.provider.rx.request(.exchangeInfo(symbol: self.symbol))
            }
            .observeOn(backgroundScheduler)
            .map([ExchangeInfo].self, atKeyPath: "data", using: decoder)
            .asObservable()
            .flatMap { Observable.from(optional: $0.first) }
            .retry()
            .take(1)
            .publish()
        
        let webserviceDepth = self.reachability.rx.isConnected
            .flatMap { [unowned self] _ in
                self.provider.rx.request(.depth(symbol: self.symbol, limit: 1000))
            }
            .observeOn(self.backgroundScheduler)
            .map(Depth.self)
            .retry()
            .publish()
        
        let socketDepth = websocket.rx.didReceiveMessage
            .observeOn(backgroundScheduler)
            .map { [unowned self] message in
                return try self.decoder.decode(LocalOrderBookPayload.self, from: message.data(using: .utf8) ?? Data())
            }
            .publish()
        
        // collect & process data
        let data = webserviceDepth
            .flatMap { depth -> Observable<(Dictionary<Double, Order>, Dictionary<Double, Order>)> in
                let bidMap: [Double: Order] = Dictionary(grouping: depth.bids, by: {$0.priceLevel})
                    .compactMapValues { $0.first }
                let askMap: [Double: Order] = Dictionary(grouping: depth.asks, by: {$0.priceLevel})
                    .compactMapValues { $0.first }
                return socketDepth
                    .filter { payload -> Bool in
                        // Drop any event where u is <= lastUpdateId in the snapshot.
                        return payload.finalUpdateId > depth.lastUpdateId
                    }
                    .skipUntil(
                        socketDepth.filter { payload -> Bool in
                            // The first processed event should have U <= lastUpdateId+1 AND u >= lastUpdateId+1.
                            (...(depth.lastUpdateId+1)).contains(payload.firstUpdateId) &&
                                ((depth.lastUpdateId+1)...).contains(payload.finalUpdateId)
                            }
                            .take(1)
                    )
                    .takeUntil(webserviceDepth)
                    .map { payload in (payload.bids, payload.asks)}
                    .startWith(([], []))
                    .scan((bidMap, askMap), accumulator: { (tuple, newTuple) -> ([Double: Order], [Double: Order]) in
                        var (bidMap, askMap) = tuple
                        let (newBids, newAsks) = newTuple
                        newBids.forEach { bid in
                            if bid.quantity == 0 {
                                bidMap.removeValue(forKey: bid.priceLevel)
                            } else {
                                bidMap.updateValue(bid, forKey: bid.priceLevel)
                            }
                        }
                        newAsks.forEach { ask in
                            if ask.quantity == 0 {
                                askMap.removeValue(forKey: ask.priceLevel)
                            } else {
                                askMap.updateValue(ask, forKey: ask.priceLevel)
                            }
                        }
                        return (bidMap, askMap)
                })
            }
        
        // available tick sizes from eExchange info.
        let digitOptions = webServiceExchangeInfo.map { ($0.minTickSize.count-5...$0.minTickSize.count-2).filter { $0 >= 0 } }
            .share(replay: 1, scope: .forever)
        
        // setup available tick sizes to drop down view.
        digitOptions.asDriver(onErrorJustReturn: [])
            .drive(onNext: { [unowned self] (digits) in
                self.dropDown.dataSource = digits.map {String($0)}
            })
            .disposed(by: disposeBag)
        
        let dropDownSelected = dropDown.rx.selectionAction.flatMap {
            Observable.from(optional: Int($0.1))
            }
            .share(replay: 1, scope: .forever)
        
        // update drow down label text.
        Observable.merge(
            digitOptions.map { $0.last ?? 0 },
            dropDownSelected
            )
            .map { "\($0)" }
            .asDriver(onErrorJustReturn: "")
            .drive(digitsDropDownLabel.rx.text)
            .disposed(by: disposeBag)                
        
        // changes of tick size.
        let digits = Observable.merge(
            digitOptions.flatMap { Observable.from(optional: $0.last) },
            dropDownSelected
        )
        
        // prepare data for displaying.
        let displayData = Observable.combineLatest(
            // data
            data,
            // tick size
            digits,
            // quantityFormatter from minTradeAmount.
            webServiceExchangeInfo.map { info -> NumberFormatter in
                var digits = info.minTradeAmount.count-2
                if digits < 0 { digits = 0 }
                return NumberFormatter.decimalFormatter(fractionDigits: digits)
            }
            )
            .observeOn(backgroundScheduler)
            .map { args -> [(CellModelType, NumberFormatter, NumberFormatter)] in
                let (bidMap, askMap) = args.0
                let digits = args.1
                let quantityFormatter = args.2
                
                let getRounded: ((_ input: Double, _ digits: Int, _ isUsingFloor: Bool) -> Double) = { input, digits, isUsingFloor in
                    let div = pow(10, Double(digits))
                    if isUsingFloor {
                        return floor(input * div)/div
                    } else {
                        return ceil(input * div)/div
                    }
                }
                let groupingMap: ((_ input: [Order], _ digits: Int, _ isUsingFloor: Bool) -> [Double: Double]) = { input, digits, isUsingFloor in
                    Dictionary(grouping: input, by: { getRounded($0.priceLevel, digits, isUsingFloor) })
                        .reduce([Double: Double](), { (result , kv) -> [Double: Double] in
                            let total = kv.value.map { $0.quantity }.reduce(0, +)
                            var newResult = result
                            newResult[kv.key] = total
                            return newResult
                        })
                }
                let sumBidMap = groupingMap(Array(bidMap.values.sorted().reversed().prefix(100)), digits, true)
                let sumAskMap = groupingMap(Array(askMap.values.sorted().prefix(100)), digits, false)
                let bidKeys = Array(sumBidMap.keys.sorted().reversed().prefix(17))
                let askKeys = Array(sumAskMap.keys.sorted().prefix(17))
                let cellModels = (0...max(bidKeys.count, askKeys.count)).map { index in
                    CellModel(
                        bid: bidKeys.indices.contains(index) ? (bidKeys[index], sumBidMap[bidKeys[index]] ?? 0) : nil,
                        ask: askKeys.indices.contains(index) ? (askKeys[index], sumAskMap[askKeys[index]] ?? 0) : nil
                    )
                }
                // price level formatter
                let formatter = NumberFormatter.decimalFormatter(fractionDigits: digits)
                
                return cellModels.map { ($0, formatter, quantityFormatter) }
        }
        
        // binding data to tableView.
        displayData.asDriver(onErrorJustReturn: [])
            .drive(tableView.rx.items(cellIdentifier: "LocalOrderBookCell", cellType: LocalOrderBookCell.self)) {  row, args, cell in
                let (cellModel, formatter, quantityFormatter) = args
                
                let bidQuantityText: String?
                let bidPriceLevelText: String?
                let bidMultiplier: CGFloat
                if let bidQuantity = cellModel.bidQuantity, let bidPriceLevel = cellModel.bidPriceLevel {
                    bidQuantityText = quantityFormatter.string(from: NSNumber(value: bidQuantity))
                    bidPriceLevelText = formatter.string(from: NSNumber(value: bidPriceLevel))
                    bidMultiplier = bidQuantity > 100 ? 1 : CGFloat(bidQuantity/100)
                } else {
                    bidQuantityText = nil
                    bidPriceLevelText = nil
                    bidMultiplier = 0
                }
                
                let askQuantityText: String?
                let askPriceLevelText: String?
                let askMultiplier: CGFloat
                if let askQuantity = cellModel.askQuantity, let askPriceLevel = cellModel.askPriceLevel {
                    askQuantityText = quantityFormatter.string(from: NSNumber(value: askQuantity))
                    askPriceLevelText = formatter.string(from: NSNumber(value: askPriceLevel))
                    askMultiplier = askQuantity > 100 ? 1 : CGFloat(askQuantity/100)
                } else {
                    askQuantityText = nil
                    askPriceLevelText = nil
                    askMultiplier = 0
                }
                
                
                cell.bidQuantity.text = bidQuantityText
                cell.bidPriceLevel.text = bidPriceLevelText
                
                cell.askQuantity.text = askQuantityText
                cell.askPriceLevel.text = askPriceLevelText
                cell.translatesAutoresizingMaskIntoConstraints = false
                
               cell.bidPriceLevelConstraint.isActive = false
                cell.bidPriceLevelConstraint = cell.bidColorView.widthAnchor.constraint(equalTo: cell.bidColorView.superview!.widthAnchor, multiplier: bidMultiplier)
                cell.bidPriceLevelConstraint.isActive = true
                
                cell.askPriceLevelConstraint.isActive = false
                cell.askPriceLevelConstraint = cell.askColorView.widthAnchor.constraint(equalTo: cell.askColorView.superview!.widthAnchor, multiplier: askMultiplier)
                cell.askPriceLevelConstraint.isActive = true
        }
        .disposed(by: disposeBag)
        
        // subscribe api, webSocket
        webServiceExchangeInfo.connect().disposed(by: disposeBag)
        webserviceDepth.connect().disposed(by: disposeBag)
        socketDepth.connect().disposed(by: disposeBag)        
    }
    
    private func setupDropDown() {
        dropDown.anchorView = digitsDropDown
        dropDown.bottomOffset = CGPoint(x: 0, y: 30)
        dropDown.direction = .bottom
        digitsDropDownGestureRecognizer.rx.event
            .subscribe { [unowned self] (_) in
                self.dropDown.show()
            }
            .disposed(by: disposeBag)
    }
    
    
}
