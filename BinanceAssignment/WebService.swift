//
//  WebService.swift
//  BinanceAssignment
//
//  Created by Kao Ming-Hsiu on 2019/12/4.
//  Copyright © 2019 ObiCat. All rights reserved.
//

import Moya

enum WebService {
    case exchangeInfo(symbol: String)
    case depth(symbol: String, limit: Int)
    case aggTrades(symbol: String, limit: Int)
}

extension WebService: TargetType {
    
    var baseURL: URL {
        switch self {
        case .exchangeInfo:
            return URL(string: "https://www.binance.com/gateway-api/v1")!
        case .depth, .aggTrades:
            return URL(string: "https://www.binance.com/api/v1")!
        }
    }
    
    var path: String {
        switch self {
        case .exchangeInfo:
            return "/public/asset-service/product/get-exchange-info"
        case .depth:
            return "/depth"
        case .aggTrades:
            return "/aggTrades"
        }
    }
    
    var method: Method {
        switch self {
        case .exchangeInfo, .depth, .aggTrades:
            return .get
        }
    }
    
    var task: Task {
        switch self {
        case .exchangeInfo(let symbol):
            return .requestParameters(parameters: ["symbol": symbol], encoding: URLEncoding.default)
        case .depth(let symbol, let limit), .aggTrades(let symbol, let limit):
            return .requestParameters(parameters: ["symbol": symbol, "limit": limit], encoding: URLEncoding.default)
        }
    }
    
    var headers: [String : String]? {
        return nil
    }
    
    var sampleData: Data {
        return Data()
    }
}
