//
//  TronJsonRpcProvider.swift
//  BlockchainSdk
//
//  Created by Andrey Chukavin on 24.03.2022.
//  Copyright © 2022 Tangem AG. All rights reserved.
//

import Foundation
import Combine
import Moya

class TronJsonRpcProvider: HostProvider {
    var host: String {
        network.url.hostOrUnknown + (tronGridApiKey == nil ? "" : " (API KEY)")
    }

    private let network: TronNetwork
    private let tronGridApiKey: String?
    private let provider: NetworkProvider<TronTarget>
    
    init(network: TronNetwork, tronGridApiKey: String?, configuration: NetworkProviderConfiguration) {
        self.network = network
        self.tronGridApiKey = tronGridApiKey
        provider = NetworkProvider<TronTarget>(configuration: configuration)
    }
    
    func getChainParameters() -> AnyPublisher<TronGetChainParametersResponse, Error> {
        requestPublisher(for: .getChainParameters(network: network))
    }

    func getAccount(for address: String) -> AnyPublisher<TronGetAccountResponse, Error> {
        requestPublisher(for: .getAccount(address: address, network: network))
    }
    
    func getAccountResource(for address: String) -> AnyPublisher<TronGetAccountResourceResponse, Error> {
        requestPublisher(for: .getAccountResource(address: address, network: network))
    }
    
    func getNowBlock() -> AnyPublisher<TronBlock, Error> {
        requestPublisher(for: .getNowBlock(network: network))
    }
    
    func broadcastHex(_ data: Data) -> AnyPublisher<TronBroadcastResponse, Error> {
        requestPublisher(for: .broadcastHex(data: data, network: network))
    }
    
    func tokenBalance(address: String, contractAddress: String) -> AnyPublisher<TronTriggerSmartContractResponse, Error> {
        requestPublisher(for: .tokenBalance(address: address, contractAddress: contractAddress, network: network))
    }
    
    func contractInfo(address: String) -> AnyPublisher<TronContractInfoResponse, Error> {
        requestPublisher(for: .contractInfo(address: address, network: network))
    }
    
    func contractEnergyUsage(sourceAddress: String, contractAddress: String, parameter: String) -> AnyPublisher<TronContractEnergyUsageResponse, Error> {
        requestPublisher(for: .contractEnergyUsage(sourceAddress: sourceAddress, contractAddress: contractAddress, parameter: parameter, network: network))
    }
    
    func tokenTransactionHistory(contractAddress: String) -> AnyPublisher<TronTokenHistoryResponse, Error> {
        requestPublisher(for: .tokenTransactionHistory(contractAddress: contractAddress, limit: 50, network: network))
    }
    
    func transactionInfo(id: String) -> AnyPublisher<TronTransactionInfoResponse, Error> {
        requestPublisher(for: .getTransactionInfoById(transactionID: id, network: network))
    }
    
    private func requestPublisher<T: Codable>(for target: TronTarget.TronTargetType, apiKey: String? = nil) -> AnyPublisher<T, Error> {
        return provider.requestPublisher(TronTarget(target, tronGridApiKey: tronGridApiKey))
            .filterSuccessfulStatusAndRedirectCodes()
            .map(T.self)
            .mapError { moyaError in
                if case .objectMapping = moyaError {
                    return WalletError.failedToParseNetworkResponse
                }
                return moyaError
            }
            .eraseToAnyPublisher()
    }
}
