//
//  AddressServiceManagerUtility.swift
//  BlockchainSdkTests
//
//  Created by skibinalexander on 28.03.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import XCTest
import CryptoKit
import TangemSdk
import WalletCore

@testable import BlockchainSdk

final class AddressServiceManagerUtility {
    
    func makeTrustWalletAddress(
        publicKey: Data,
        for blockchain: BlockchainSdk.Blockchain
    ) throws -> String {
        if let coin = CoinType(blockchain) {
            return try WalletCoreAddressService(coin: coin, publicKeyType: .init(blockchain)).makeAddress(from: publicKey)
        } else {
            throw NSError(domain: "__ AddressServiceManagerUtility __ error make address from TrustWallet address service", code: -1)
        }
    }
    
    func makeTangemAddress(
        publicKey: Data,
        for blockchain: BlockchainSdk.Blockchain,
        addressType: AddressType?
    ) throws -> String {
        if let addressType = addressType {
            let addresses = try blockchain.makeAddresses(from: publicKey, with: nil)
            if let address = addresses.first(where: { $0.type == addressType }) {
                return address.value
            } else {
                throw NSError(domain: "__ AddressServiceManagerUtility __ error make address from BlockchainSdk address service", code: -1)
            }
        } else {
            return try blockchain.getAddressService().makeAddress(from: publicKey)
        }
    }
    
}
