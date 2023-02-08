import Foundation
import TangemSdk
import stellarsdk
import BitcoinCore

struct BitcoinBlockchainAssembly: BlockchainAssemblyProtocol {
    
    static func canAssembly(blockchain: Blockchain) -> Bool {
        return blockchain == .bitcoin(testnet: blockchain.isTestnet)
    }
    
    static func assembly(with input: BlockchainAssemblyInput) throws -> AssemblyWallet {
        return try BitcoinWalletManager(wallet: input.wallet).then {
            let network: BitcoinNetwork = input.blockchain.isTestnet ? .testnet : .mainnet
            let bitcoinManager = BitcoinManager(networkParams: network.networkParams,
                                                walletPublicKey: input.wallet.publicKey.blockchainKey,
                                                compressedWalletPublicKey: try Secp256k1Key(with: input.wallet.publicKey.blockchainKey).compress(),
                                                bip: input.pairPublicKey == nil ? .bip84 : .bip141)
            
            $0.txBuilder = BitcoinTransactionBuilder(bitcoinManager: bitcoinManager, addresses: input.wallet.addresses)
            
            var providers = [AnyBitcoinNetworkProvider]()
            
            
            providers.append(makeBlockBookUtxoProvider(with: input, for: .NowNodes).eraseToAnyBitcoinNetworkProvider())
            
            if !input.blockchain.isTestnet {
                providers.append(makeBlockBookUtxoProvider(with: input, for: .GetBlock).eraseToAnyBitcoinNetworkProvider())
                providers.append(makeInfoNetworkProvider(with: input).eraseToAnyBitcoinNetworkProvider())
            }
            
            providers.append(
                contentsOf: makeBlockchairNetworkProviders(
                    endpoint: .bitcoin(testnet: input.blockchain.isTestnet),
                    with: input
                )
            )
            
            providers.append(
                makeBlockcypherNetworkProvider(
                    endpoint: .bitcoin(testnet: input.blockchain.isTestnet),
                    with: input
                )
                .eraseToAnyBitcoinNetworkProvider()
            )
            
            $0.networkService = BitcoinNetworkService(providers: providers)
        }
    }
    
}
