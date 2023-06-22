//
//  WalletCoreAddressService.swift
//  BlockchainSdk
//
//  Created by skibinalexander on 12.01.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import WalletCore

public struct WalletCoreAddressService {
    private let coin: CoinType
    private let publicKeyType: PublicKeyType

    // MARK: - Init

    public init(coin: CoinType, publicKeyType: PublicKeyType) {
        self.coin = coin
        self.publicKeyType = publicKeyType
    }
}

// MARK: - Convenience init

extension WalletCoreAddressService {
    public init(coin: CoinType) {
        self.init(coin: coin, publicKeyType: coin.publicKeyType)
    }

    public init(blockchain: Blockchain) {
        let coin = CoinType(blockchain)!
        self.init(coin: coin)
    }
}

// MARK: - AddressProvider

extension WalletCoreAddressService: AddressProvider {
    public func makeAddress(for publicKey: Wallet.PublicKey, with addressType: AddressType) throws -> PlainAddress {
        guard let walletCorePublicKey = PublicKey(tangemPublicKey: publicKey.blockchainKey, publicKeyType: publicKeyType) else {
            throw TWError.makeAddressFailed
        }

        let address = AnyAddress(publicKey: walletCorePublicKey, coin: coin).description
        return PlainAddress(value: address, publicKey: publicKey, type: addressType)
    }
}

// MARK: - AddressValidator

extension WalletCoreAddressService: AddressValidator {
    public func validate(_ address: String) -> Bool {
        return AnyAddress(string: address, coin: coin) != nil
    }
}

extension WalletCoreAddressService {
    enum TWError: Error {
        case makeAddressFailed
    }
}
