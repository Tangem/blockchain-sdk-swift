//
//  TronTarget.swift
//  BlockchainSdk
//
//  Created by Andrey Chukavin on 24.03.2022.
//  Copyright © 2022 Tangem AG. All rights reserved.
//

import Foundation
import Moya

struct TronTarget: TargetType {
    enum TronTargetType {
        case getAccount(address: String, network: TronNetwork)
        case getAccountResource(address: String, network: TronNetwork)
        case getNowBlock(network: TronNetwork)
        case broadcastHex(data: Data, network: TronNetwork)
        case tokenBalance(address: String, contractAddress: String, network: TronNetwork)
        case tokenTransactionHistory(contractAddress: String, limit: Int, network: TronNetwork)
        case getTransactionInfoById(transactionID: String, network: TronNetwork)
    }
    
    let type: TronTargetType
    let tronGridApiKey: String?
    
    init(_ type: TronTargetType, tronGridApiKey: String?) {
        self.type = type
        self.tronGridApiKey = tronGridApiKey
    }
    
    var baseURL: URL {
        switch type {
        case .getAccount(_, let network):
            return network.url
        case .getAccountResource(_, let network):
            return network.url
        case .getNowBlock(let network):
            return network.url
        case .broadcastHex(_, let network):
            return network.url
        case .tokenBalance(_, _, let network):
            return network.url
        case .tokenTransactionHistory(_, _, let network):
            return network.url
        case .getTransactionInfoById(_, let network):
            return network.url
        }
    }
    
    var path: String {
        switch type {
        case .getAccount:
            return "/wallet/getaccount"
        case .getAccountResource:
            return "/wallet/getaccountresource"
        case .getNowBlock:
            return "/wallet/getnowblock"
        case .broadcastHex:
            return "/wallet/broadcasthex"
        case .tokenBalance:
            return "/wallet/triggersmartcontract"
        case .tokenTransactionHistory(let contractAddress, _, _):
            return "/v1/contracts/\(contractAddress)/transactions"
        case .getTransactionInfoById:
            return "/walletsolidity/gettransactioninfobyid"
        }
    }
    
    var method: Moya.Method {
        switch type {
        case .tokenTransactionHistory:
            return .get
        default:
            return .post
        }
    }
    
    var task: Task {
        switch type {
        case .getAccount(let address, _), .getAccountResource(let address, _):
            let request = TronGetAccountRequest(address: address, visible: true)
            return .requestJSONEncodable(request)
        case .getNowBlock:
            return .requestPlain
        case .broadcastHex(let data, _):
            let request = TronBroadcastRequest(transaction: data.hex)
            return .requestJSONEncodable(request)
        case .tokenBalance(let address, let contractAddress, _):
            let hexAddress = TronAddressService.toHexForm(address, length: 64) ?? ""
            
            let request = TronTriggerSmartContractRequest(
                owner_address: address,
                contract_address: contractAddress,
                function_selector: "balanceOf(address)",
                parameter: hexAddress,
                visible: true
            )
            return .requestJSONEncodable(request)
        case .tokenTransactionHistory(_, let limit, _):
            let parameters: [String: Any] = [
                "only_confirmed": true,
                "limit": limit,
            ]
            return .requestParameters(parameters: parameters, encoding: URLEncoding.default)
        case .getTransactionInfoById(let transactionID, _):
            let request = TronTransactionInfoRequest(value: transactionID)
            return .requestJSONEncodable(request)
        }
    }
    
    var headers: [String : String]? {
        var headers = [
            "Accept": "application/json",
            "Content-Type": "application/json",
        ]
        
        if let tronGridApiKey = tronGridApiKey {
            headers["TRON-PRO-API-KEY"] = tronGridApiKey
        }
        
        return headers
    }
}
