//
//  BlockchairTarget.swift
//  BlockchainSdk
//
//  Created by Alexander Osokin on 14.02.2020.
//  Copyright © 2020 Tangem AG. All rights reserved.
//

import Foundation
import Moya

enum BlockchairEndpoint: String {
	case bitcoin = "bitcoin"
    case bitcoinCash = "bitcoin-cash"
	case litecoint = "litecoin"
    
    var blockchain: Blockchain {
        switch self {
        case .bitcoin:
            return .bitcoin(testnet: false)
        case .bitcoinCash:
            return .bitcoinCash(testnet: false)
		case .litecoint:
			return .litecoin
        }
    }
}

enum BlockchairTarget: TargetType {
	case address(address:String, endpoint: BlockchairEndpoint = .bitcoinCash, transactionDetails: Bool)
    case fee(endpoint: BlockchairEndpoint = .bitcoinCash)
    case send(txHex: String, endpoint: BlockchairEndpoint = .bitcoinCash)
    
    var baseURL: URL {
        var endpointString = ""
        
        switch self {
        case .address(_, let endpoint, _):
            endpointString = endpoint.rawValue
        case .fee(let endpoint):
            endpointString = endpoint.rawValue
        case .send(_, let endpoint):
            endpointString = endpoint.rawValue
        }
        
        return URL(string: "https://api.blockchair.com/\(endpointString)")!
    }
    
    var path: String {
        switch self {
        case .address(let address, _, _):
            return "/dashboards/address/\(address)"
        case .fee:
            return "/stats"
        case .send:
            return "/push/transaction"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .address, .fee:
            return .get
        case .send:
            return .post
        }
    }
    
    var sampleData: Data {
        return Data()
    }
    
    var task: Task {
        var parameters =  ["key": apiKey]
        switch self {
        case .address(_, _, let details):
            parameters["transaction_details"] = "\(details)"
        case .fee:
            break
        case .send(let txHex, _):
            parameters["data"] = txHex
        }
        return .requestParameters(parameters: parameters, encoding: URLEncoding.default)
    }
    
    var headers: [String: String]? {
        switch self {
        case .address, .fee:
            return ["Content-Type": "application/json"]
        case .send:
            return ["Content-Type": "application/x-www-form-urlencoded"]
        }
    }
    
    private var apiKey: String {
        return "A___0Shpsu4KagE7oSabrw20DfXAqWlT"
    }
}
