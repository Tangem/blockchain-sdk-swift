//
//  VeChainTarget.swift
//  BlockchainSdk
//
//  Created by Andrey Fedorov on 18.12.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import Moya

struct VeChainTarget {
    let baseURL: URL
    let target: Target
}

// MARK: - Auxiliary types

extension VeChainTarget {
    enum Target {
        case viewAccount(address: String)
        case viewBlock(request: VeChainNetworkParams.BlockInfo)
        case sendTransaction(rawTransaction: String)
        case transactionStatus(transactionHash: String, includePending: Bool, rawOutput: Bool)
    }
}

// MARK: - TargetType protocol conformance

extension VeChainTarget: TargetType {
    var path: String {
        switch target {
        case .viewAccount(let address):
            return "/accounts/\(address)"
        case .viewBlock(let request):
            let path: String
            switch request.requestType {
            case .specificWithId(let blockId):
                path = blockId
            case .specificWithNumber(let blockNumber):
                path = String(blockNumber)
            case .latest:
                path = "best"
            case .latestFinalized:
                path = "finalized"
            }
            return "/blocks/\(path)"
        case .sendTransaction:
            return "/transactions"
        case .transactionStatus(let transactionHash, _, _):
            return "/transactions/\(transactionHash)"
        }
    }
    
    var method: Moya.Method {
        switch target {
        case .viewAccount,
             .viewBlock,
             .transactionStatus:
            return .get
        case .sendTransaction:
            return .post
        }
    }
    
    var task: Moya.Task {
        switch target {
        case .viewAccount,
             .viewBlock:
            return .requestPlain
        case .transactionStatus(_, let includePending, let rawOutput):
            let parameters = [
                "pending": includePending,
                "raw": rawOutput,
            ]
            return .requestParameters(parameters: parameters, encoding: URLEncoding.queryString)
        case .sendTransaction(let rawTransaction):
            return .requestJSONEncodable(VeChainNetworkParams.Transaction(raw: rawTransaction))
        }
    }
    
    var headers: [String: String]? {
        return [
            "Content-Type": "application/json",
            "Accept": "application/json",
        ]
    }
}
