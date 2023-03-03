//
//  BlockchainSdkConfig.swift
//  BlockchainSdk
//
//  Created by Alexander Osokin on 14.12.2020.
//  Copyright © 2020 Tangem AG. All rights reserved.
//

import Foundation

public struct BlockchainSdkConfig {
    let blockchairApiKeys: [String]
    let blockcypherTokens: [String]
    let infuraProjectId: String
    let nowNodesApiKey: String
    let getBlockApiKey: String
    let tronGridApiKey: String
    let toncenterApiKey: String
    let quickNodeSolanaCredentials: QuickNodeCredentials
    let quickNodeBscCredentials: QuickNodeCredentials
    let blockscoutCredentials: NetworkProviderConfiguration.Credentials
    let defaultNetworkProviderConfiguration: NetworkProviderConfiguration
    let networkProviderConfigurations: [Blockchain: NetworkProviderConfiguration]

    public init(
        blockchairApiKeys: [String],
        blockcypherTokens: [String],
        infuraProjectId: String,
        nowNodesApiKey: String,
        getBlockApiKey: String,
        tronGridApiKey: String,
        toncenterApiKey: String,
        quickNodeSolanaCredentials: QuickNodeCredentials,
        quickNodeBscCredentials: QuickNodeCredentials,
        blockscoutCredentials: NetworkProviderConfiguration.Credentials,
        defaultNetworkProviderConfiguration: NetworkProviderConfiguration = .init(),
        networkProviderConfigurations: [Blockchain: NetworkProviderConfiguration] = [:]
    ) {
        self.blockchairApiKeys = blockchairApiKeys
        self.blockcypherTokens = blockcypherTokens
        self.infuraProjectId = infuraProjectId
        self.nowNodesApiKey = nowNodesApiKey
        self.getBlockApiKey = getBlockApiKey
        self.tronGridApiKey = tronGridApiKey
        self.toncenterApiKey = toncenterApiKey
        self.quickNodeSolanaCredentials = quickNodeSolanaCredentials
        self.quickNodeBscCredentials = quickNodeBscCredentials
        self.blockscoutCredentials = blockscoutCredentials
        self.defaultNetworkProviderConfiguration = defaultNetworkProviderConfiguration
        self.networkProviderConfigurations = networkProviderConfigurations
    }

    func networkProviderConfiguration(for blockchain: Blockchain) -> NetworkProviderConfiguration {
        networkProviderConfigurations[blockchain] ?? defaultNetworkProviderConfiguration
    }
}

public extension BlockchainSdkConfig {
    struct QuickNodeCredentials {
        let apiKey: String
        let subdomain: String
        
        public init(apiKey: String, subdomain: String) {
            self.apiKey = apiKey
            self.subdomain = subdomain
        }
    }
}
