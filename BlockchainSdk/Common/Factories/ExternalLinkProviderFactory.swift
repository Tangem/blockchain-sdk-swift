//
//  ExternalLinkProviderFactory.swift
//  BlockchainSdk
//
//  Created by Sergey Balashov on 06.09.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation

public struct ExternalLinkProviderFactory {
    public init() {}

    public func makeProvider(for blockchain: Blockchain) -> ExternalLinkProvider {
        let isTestnet = blockchain.isTestnet

        switch blockchain {
        case .bitcoin:
            return BitcoinExternalLinkProvider(isTestnet: isTestnet)
        case .litecoin:
            return LitecoinExternalLinkProvider()
        case .stellar:
            return StellarExternalLinkProvider(isTestnet: isTestnet)
        case .ethereum:
            return EthereumExternalLinkProvider(isTestnet: isTestnet)
        case .ethereumPoW:
            return EthereumPoWExternalLinkProvider(isTestnet: isTestnet)
        case .ethereumFair:
            return EthereumFairExternalLinkProvider()
        case .ethereumClassic:
            return EthereumClassicExternalLinkProvider(isTestnet: isTestnet)
        case .rsk:
            return RSKExternalLinkProvider()
        case .bitcoinCash:
            return BitcoinCashExternalLinkProvider(isTestnet: isTestnet)
        case .binance:
            return BinanceExternalLinkProvider(isTestnet: isTestnet)
        case .cardano:
            return CardanoExternalLinkProvider()
        case .xrp:
            return XRPExternalLinkProvider()
        case .ducatus:
            return DucatusExternalLinkProvider()
        case .tezos:
            return TezosExternalLinkProvider()
        case .dogecoin:
            return DogecoinExternalLinkProvider()
        case .bsc:
            return BSCExternalLinkProvider(isTestnet: isTestnet)
        case .polygon:
            return PolygonExternalLinkProvider(isTestnet: isTestnet)
        case .avalanche:
            return AvalancheExternalLinkProvider(isTestnet: isTestnet)
        case .solana:
            return SolanaExternalLinkProvider(isTestnet: isTestnet)
        case .fantom:
            return FantomExternalLinkProvider(isTestnet: isTestnet)
        case .polkadot:
            return PolkadotExternalLinkProvider(isTestnet: isTestnet)
        case .kusama:
            return KusamaExternalLinkProvider()
        case .azero:
            return AZeroExternalLinkProvider()
        case .tron:
            return TronExternalLinkProvider(isTestnet: isTestnet)
        case .arbitrum:
            return ArbitrumExternalLinkProvider(isTestnet: isTestnet)
        case .dash:
            return DashExternalLinkProvider(isTestnet: isTestnet)
        case .gnosis:
            return GnosisExternalLinkProvider()
        case .optimism:
            return OptimismExternalLinkProvider(isTestnet: isTestnet)
        case .saltPay:
            return SaltPayExternalLinkProvider()
        case .ton:
            return TonExternalLinkProvider(isTestnet: isTestnet)
        case .kava:
            return KavaExternalLinkProvider(isTestnet: isTestnet)
        case .kaspa:
            return KaspaExternalLinkProvider()
        case .ravencoin:
            return RavencoinExternalLinkProvider(isTestnet: isTestnet)
        case .cosmos:
            return CosmosExternalLinkProvider(isTestnet: isTestnet)
        case .terraV1:
            return TerraV1ExternalLinkProvider()
        case .terraV2:
            return TerraV2ExternalLinkProvider()
        case .cronos:
            return CronosExternalLinkProvider()
        case .telos:
            return TelosExternalLinkProvider(isTestnet: isTestnet)
        case .octa:
            return OctaExternalLinkProvider()
        case .chia:
            return ChiaExternalLinkProvider(isTestnet: isTestnet)
        case .near:
            return NEARExternalLinkProvider(isTestnet: isTestnet)
        }
    }
}
