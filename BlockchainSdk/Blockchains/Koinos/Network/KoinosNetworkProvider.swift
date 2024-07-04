//
//  KoinosNetworkProvider.swift
//  BlockchainSdk
//
//  Created by Aleksei Muraveinik on 23.05.24.
//  Copyright © 2024 Tangem AG. All rights reserved.
//

import BigInt
import Combine

class KoinosNetworkProvider: HostProvider {
    var host: String {
        node.url.absoluteString
    }
    
    private let node: NodeInfo
    private let provider: NetworkProvider<KoinosTarget>
    private let koinosNetworkParams: KoinosNetworkParams
    
    init(
        node: NodeInfo,
        koinosNetworkParams: KoinosNetworkParams,
        configuration: NetworkProviderConfiguration
    ) {
        self.node = node
        provider = NetworkProvider<KoinosTarget>(configuration: configuration)
        self.koinosNetworkParams = koinosNetworkParams
    }
    
    func getInfo(address: String) -> AnyPublisher<KoinosAccountInfo, Error> {
        Publishers.Zip(
            getKoinBalance(address: address),
            getRC(address: address)
        )
        .map { balance, mana in
            KoinosAccountInfo(
                koinBalance: balance,
                mana: mana
            )
        }
        .eraseToAnyPublisher()
    }
    
    func getNonce(address: String) -> AnyPublisher<KoinosAccountNonce, Error> {
        requestPublisher(
            for: .getNonce(address: address),
            withResponseType: KoinosMethod.GetAccountNonce.Response.self
        )
        .tryMap(KoinosDTOMapper.convertNonce)
        .eraseToAnyPublisher()
    }
    
    func getRCLimit() -> AnyPublisher<BigUInt, Error> {
        getResourceLimits()
            .map { limits in
                Constants.maxDiskStorageLimit * limits.diskStorageCost
                    + Constants.maxNetworkLimit * limits.networkBandwidthCost
                    + Constants.maxComputeLimit * limits.computeBandwidthCost
            }
            .eraseToAnyPublisher()
    }
    
    func submitTransaction(transaction: KoinosProtocol.Transaction) -> AnyPublisher<KoinosTransactionEntry, Error> {
        requestPublisher(
            for: .submitTransaction(transaction: transaction),
            withResponseType: KoinosMethod.SubmitTransaction.Response.self
        )
        .map(\.receipt)
        .tryMap(KoinosDTOMapper.convertTransactionEntry)
        .eraseToAnyPublisher()
    }
    
    func isTransactionExist(transactionID: String) -> AnyPublisher<Bool, Error> {
        requestPublisher(
            for: .getTransaction(transactionID: transactionID),
            withResponseType: KoinosMethod.GetTransaction.Response.self
        )
        .map { $0.transactions != nil }
        .eraseToAnyPublisher()
    }
}

private extension KoinosNetworkProvider {
    func getKoinBalance(address: String) -> AnyPublisher<UInt64, Error> {
        Result {
            try Koinos_Contracts_Token_balance_of_arguments.with {
                $0.owner = address.base58DecodedData
            }
            .serializedData()
            .base64URLEncodedString()
        }
        .publisher
        .withWeakCaptureOf(self)
        .flatMap { provider, args in
            provider.requestPublisher(
                for: .getKoinBalance(args: args),
                withResponseType: KoinosMethod.ReadContract.Response.self
            )
        }
        .tryMap(KoinosDTOMapper.convertKoinBalance)
        .eraseToAnyPublisher()
    }
    
    func getRC(address: String) -> AnyPublisher<UInt64, Error> {
        requestPublisher(
            for: .getRc(address: address),
            withResponseType: KoinosMethod.GetAccountRC.Response.self
        )
        .map(KoinosDTOMapper.convertAccountRC)
        .eraseToAnyPublisher()
    }
    
    func getResourceLimits() -> AnyPublisher<KoinosResourceLimitData, Error> {
        requestPublisher(
            for: .getResourceLimits,
            withResponseType: KoinosMethod.GetResourceLimits.Response.self
        )
        .tryMap(KoinosDTOMapper.convertResourceLimitData)
        .eraseToAnyPublisher()
    }
    
    func requestPublisher<T: Decodable>(
        for target: KoinosTarget.KoinosTargetType,
        withResponseType: T.Type
    ) -> AnyPublisher<T, Error> {
        provider.requestPublisher(KoinosTarget(node: node, koinosNetworkParams: koinosNetworkParams, target))
            .filterSuccessfulStatusAndRedirectCodes()
            .map(JSONRPC.Response<T, JSONRPC.APIError>.self, using: .withSnakeCaseStrategy)
            .tryMap { try $0.result.get() }
            .eraseToAnyPublisher()
    }
}

private extension KoinosNetworkProvider {
    // These constants were calculated for us by the Koinos developers and provided to us in a Telegram chat.
    enum Constants {
        static let maxDiskStorageLimit: BigUInt = 118
        static let maxNetworkLimit: BigUInt = 408
        static let maxComputeLimit: BigUInt = 1_000_000
    }
}
