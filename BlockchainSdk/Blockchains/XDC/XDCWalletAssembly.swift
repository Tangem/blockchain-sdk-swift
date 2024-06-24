//
//  XDCWalletAssembly.swift
//  BlockchainSdk
//
//  Created by Alexander Osokin on 17.01.2024.
//  Copyright © 2024 Tangem AG. All rights reserved.
//

import Foundation

struct XDCWalletAssembly: WalletManagerAssembly {
    func make(with input: WalletManagerAssemblyInput) throws -> WalletManager {
        guard let chainId = input.blockchain.chainId else {
            throw EthereumWalletAssemblyError.chainIdNotFound
        }

        let txBuilder = XDCTransactionBuilder(chainId: chainId)
        let networkService = XDCNetworkService(
            decimals: input.blockchain.decimalCount,
            providers: networkProviderAssembly.makeEthereumJsonRpcProviders(with: input),
            blockcypherProvider: nil,
            abiEncoder: WalletCoreABIEncoder()
        )

        return EthereumWalletManager(wallet: input.wallet, txBuilder: txBuilder, networkService: networkService)
    }
}
