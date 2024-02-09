//
//  HederaTarget.swift
//  BlockchainSdk
//
//  Created by Andrey Fedorov on 26.01.2024.
//  Copyright © 2024 Tangem AG. All rights reserved.
//

import Foundation
import Moya

struct HederaTarget {
    let config: HederaBaseURLConfig
    let target: Target
}

// MARK: - Auxiliary types

extension HederaTarget {
    enum Target {
        case createAccount(networkId: String, publicKey: String, cardId: String, cardPublicKey: String)
        case getAccounts(publicKey: String)
        case getExchangeRate
    }
}

// MARK: - TargetType protocol conformance

extension HederaTarget: TargetType {
    var baseURL: URL {
        switch target {
        case .createAccount:
            return config.helperNodeBaseURL
        case .getAccounts, .getExchangeRate:
            return config.mirrorNodeBaseURL
        }
    }

    var path: String {
        switch target {
        case .createAccount:
            return "network-account"
        case .getAccounts:
            return "accounts"
        case .getExchangeRate:
            return "network/exchangerate"
        }
    }

    var method: Moya.Method {
        switch target {
        case .createAccount:
            return .post
        case .getAccounts, .getExchangeRate:
            return .get
        }
    }

    var task: Moya.Task {
        switch target {
        case .createAccount(let networkId, let publicKey, _, _):
            let params = HederaNetworkParams.CreateAccount(networkId: networkId, publicWalletKey: publicKey)
            return .requestJSONEncodable(params)
        case .getAccounts(let publicKey):
            let parameters: [String: Any] = [
                "balance": false,
                "account.publickey": publicKey,
            ]
            let encoding = URLEncoding(
                destination: URLEncoding.queryString.destination,
                arrayEncoding: URLEncoding.queryString.arrayEncoding,
                boolEncoding: .literal
            )
            return .requestParameters(parameters: parameters, encoding: encoding)
        case .getExchangeRate:
            return .requestPlain
        }
    }

    var headers: [String: String]? {
        var headers = [
            "Content-Type": "application/json",
            "Accept": "application/json",
        ]

        switch target {
        case .createAccount(_, _, let cardId, let cardPublicKey):
            headers["card_id"] = cardId
            headers["card_public_key"] = cardPublicKey
        case .getAccounts, .getExchangeRate:
            break
        }

        return headers
    }
}
