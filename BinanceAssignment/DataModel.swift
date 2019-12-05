//
//  DataModel.swift
//  BinanceAssignment
//
//  Created by Kao Ming-Hsiu on 2019/12/4.
//  Copyright © 2019 ObiCat. All rights reserved.
//

import Foundation

enum LocalOrderBookPayloadDecodeError: Error {
    case errorFormat
}

struct Order: Decodable, Comparable {
    let priceLevel: Double
    let quantity: Double
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let pq = try container.decode([String].self)
        guard let priceLevel = Double(pq[0]), let quantity = Double(pq[1]) else { throw LocalOrderBookPayloadDecodeError.errorFormat }        
        self.priceLevel = priceLevel
        self.quantity = quantity
    }
    
    static func < (lhs: Order, rhs: Order) -> Bool {
        return lhs.priceLevel < rhs.priceLevel
    }
}

struct Depth: Decodable {
    let lastUpdateId: Int
    let asks: [Order]
    let bids: [Order]
}

struct LocalOrderBookPayload: Decodable {
    
    /// e
    let eventType: String
    /// E
    let eventTime: Date
    /// s
    let symbol: String
    /// U
    let firstUpdateId: Int
    /// u
    let finalUpdateId: Int
    /// b
    let bids: [Order]
    /// a
    let asks: [Order]
    
    enum CodingKeys: String, CodingKey {
        case eventType = "e"
        case eventTime = "E"
        case symbol = "s"
        case firstUpdateId = "U"
        case finalUpdateId = "u"
        case bids = "b"
        case asks = "a"
    }
    
}

struct ExchangeInfo: Decodable {
    let baseAsset: String
    let quoteAsset: String
    let minTradeAmount: String
    let minTickSize: String
    let minOrderValue: String
    let maxMarketOrderQty: String?
    let minMarketOrderQty: String?        
}

struct AggTrade: Decodable {
    
    let aggregateTradeId: Int
    let price: Double
    let quantity: Double
    let firstTradeId: Int
    let lastTradeId: Int
    let tradeTime: Date
    let isTheMarketMaker: Bool
    let ignore: Bool
    
    enum CodingKeys: String, CodingKey {
        case aggregateTradeId = "a"
        case price = "p"
        case quantity = "q"
        case firstTradeId = "f"
        case lastTradeId = "l"
        case tradeTime = "T"
        case isTheMarketMaker = "m"
        case ignore = "M"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        aggregateTradeId = try container.decode(Int.self, forKey: .aggregateTradeId)
        price = Double(try container.decode(String.self, forKey: .price)) ?? 0
        quantity = Double(try container.decode(String.self, forKey: .quantity)) ?? 0
        firstTradeId = try container.decode(Int.self, forKey: .firstTradeId)
        lastTradeId = try container.decode(Int.self, forKey: .lastTradeId)
        tradeTime = try container.decode(Date.self, forKey: .tradeTime)
        isTheMarketMaker = try container.decode(Bool.self, forKey: .isTheMarketMaker)
        ignore = try container.decode(Bool.self, forKey: .ignore)        
    }
}
