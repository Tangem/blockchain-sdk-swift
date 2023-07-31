//
//  DerivationConfigV1.swift
//  BlockchainSdk
//
//  Created by Sergey Balashov on 24.05.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation

/// Documentation:
/// Types:
/// - `Stellar`, `Solana`. According to `SEP0005`
/// https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0005.md
/// - `Cardano`. According to  `CIP1852`
/// https://cips.cardano.org/cips/cip1852/
/// - `All else`. According to `BIP44`
/// https://github.com/satoshilabs/slips/blob/master/slip-0044.md
public struct DerivationConfigV1: DerivationConfig {
    public func derivationPath(for blockchain: Blockchain) -> String {
        switch blockchain {
        case .bitcoin:
            return "m/44'/0'/0'/0/0"
        case .litecoin:
            return "m/44'/2'/0'/0/0"
        case .stellar:
            return "m/44'/148'/0'"
        case .solana:
            return "m/44'/501'/0'"
        case .cardano:
            return "m/1852'/1815'/0'/0/0"
        case .bitcoinCash:
            return "m/44'/145'/0'/0/0"
        case .ethereum, .ethereumPoW, .ethereumFair, .saltPay, .octa:
            return "m/44'/60'/0'/0/0"
        case .ethereumClassic:
            return "m/44'/61'/0'/0/0"
        case .rsk:
            return "m/44'/137'/0'/0/0"
        case .binance:
            return "m/44'/714'/0'/0/0"
        case .xrp:
            return "m/44'/144'/0'/0/0"
        case .ducatus:
            return "m/44'/0'/0'/0/0"
        case .tezos:
            return "m/44'/1729'/0'/0/0"
        case .dogecoin:
            return "m/44'/3'/0'/0/0"
        case .bsc:
            return "m/44'/9006'/0'/0/0"
        case .polygon:
            return "m/44'/966'/0'/0/0"
        case .avalanche:
            return "m/44'/9000'/0'/0/0"
        case .fantom:
            return "m/44'/1007'/0'/0/0"
        case .polkadot:
            return "m/44'/354'/0'/0/0"
        case .kusama:
            return "m/44'/434'/0'/0/0"
        case .azero:
            return "m/44'/643'/0'/0'/0'"
        case .tron:
            return "m/44'/195'/0'/0/0"
        case .arbitrum:
            return "m/44'/9001'/0'/0/0"
        case .dash:
            return "m/44'/5'/0'/0/0"
        case .gnosis:
            return "m/44'/700'/0'/0/0"
        case .optimism:
            return "m/44'/614'/0'/0/0"
        case .ton:
            return "m/44'/607'/0'/0/0"
        case .kava:
            return "m/44'/459'/0'/0/0"
        case .kaspa:
            return "m/44'/111111'/0'/0/0"
        case .ravencoin:
            return "m/44'/175'/0'/0/0"
        case .cosmos:
            return "m/44'/118'/0'/0/0"
        case .terraV1, .terraV2:
            return "m/44'/330'/0'/0/0"
        case .cronos:
            return "m/44'/10000025'/0'/0/0"
        case .telos:
            return "m/44'/977'/0'/0/0"
        }
    }
}
