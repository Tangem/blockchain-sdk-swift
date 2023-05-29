//
//  Wallet.swift
//  BlockchainSdk
//
//  Created by Alexander Osokin on 04.12.2019.
//  Copyright © 2019 Tangem AG. All rights reserved.
//

import Foundation
import TangemSdk

public struct Wallet {
    public let blockchain: Blockchain
    public let addresses: Addresses
    
    public internal(set) var amounts: [Amount.AmountType:Amount] = [:]
    public internal(set) var transactions: [Transaction] = []
    
    public var defaultAddress: WalletAddress { addresses.default }
    public var defaultPublicKey: Wallet.PublicKey { defaultAddress.publicKey }

    public var address: String { defaultAddress.address.value }
    
    public var isEmpty: Bool {
        return amounts.filter { $0.key != .reserve && !$0.value.isZero }.isEmpty
    }
    
    public var hasPendingTx: Bool {
        return !transactions.filter { $0.status == .unconfirmed }.isEmpty
    }
    
    public var pendingOutgoingTransactions: [Transaction] {
        transactions.filter { tx in
            tx.status == .unconfirmed &&
            tx.destinationAddress != .unknown &&
            addresses.all.contains(where: { $0.address.value == tx.sourceAddress })
        }
    }
    
    public var pendingIncomingTransactions: [Transaction] {
        transactions.filter { tx in
            tx.status == .unconfirmed &&
            tx.sourceAddress != .unknown &&
            addresses.all.contains(where: { $0.address.value == tx.destinationAddress })
        }
    }
    
    public var pendingBalance: Decimal {
        pendingOutgoingTransactions
            .reduce(0, { $0 + $1.amount.value + $1.fee.amount.value })
    }

    @available(*, deprecated, message: "Use xpubKeys with each address support")
    public var xpubKey: String? {
        guard let key = defaultAddress.publicKey.derivedKey else { return nil }

        return try? key.serialize(for: blockchain.isTestnet ? .testnet : .mainnet)
    }
    
    public var xpubKeys: [String] {
        addresses.all
            .compactMap {
                try? $0.publicKey.derivedKey?.serialize(
                    for: blockchain.isTestnet ? .testnet : .mainnet
                )
            }
    }
    
    @available(*, deprecated, message: "Use init(blockchain:, addresses:)")
    init(blockchain: Blockchain, addresses: [Address], publicKey: PublicKey) {
        self.blockchain = blockchain
        
        assert(
            addresses.contains(where: { $0.type == .default }),
            "Addresses have to contains default address"
        )
        
        let walletAddresses = addresses.map {
            WalletAddress(address: $0, publicKey: publicKey)
        }
        
        self.addresses = .init(
            default: walletAddresses.first(where: { $0.address.type == .default })!,
            legacy: walletAddresses.first(where: { $0.address.type == .legacy })
        )
    }
    
    init(blockchain: Blockchain, addresses: Addresses) {
        self.blockchain = blockchain
        self.addresses = addresses
    }
    
    public func hasPendingTx(for amountType: Amount.AmountType) -> Bool {
        return !transactions.filter { $0.status == .unconfirmed && $0.amount.type == amountType }.isEmpty
    }
    
    /// Explore URL for specific address
    /// - Parameter address: If nil, default address will be used
    /// - Returns: URL
    public func getExploreURL(for address: String? = nil, token: Token? = nil) -> URL? {
        let address = address ?? self.address
        return blockchain.getExploreURL(from: address, tokenContractAddress: token?.contractAddress)
    }
    
    /// Share string for specific address
    /// - Parameter address: If nil, default address will be used
    /// - Returns: String to share
    public func getShareString(for address: String? = nil) -> String {
        let address = address ?? self.address
        return blockchain.getShareString(from: address)
    }
    
    public mutating func add(coinValue: Decimal) {
        let coinAmount = Amount(with: blockchain, type: .coin, value: coinValue)
        add(amount: coinAmount)
    }
    
    public mutating func add(reserveValue: Decimal) {
        let reserveAmount = Amount(with: blockchain, type: .reserve, value: reserveValue)
        add(amount: reserveAmount)
    }
    
    @discardableResult
    public mutating func add(tokenValue: Decimal, for token: Token) -> Amount {
        let tokenAmount = Amount(with: token, value: tokenValue)
        add(amount: tokenAmount)
        return tokenAmount
    }
    
    public mutating func add(amount: Amount) {
        amounts[amount.type] = amount
    }
    
    // MARK: - Internal
    
    mutating func clearAmounts() {
        amounts = [:]
    }
    
    mutating func add(transaction: Transaction) {
        var tx = transaction
        tx.date = Date()
        transactions.append(tx)
    }
    
    mutating func addPendingTransaction(amount: Amount,
                                        fee: Amount,
                                        sourceAddress: String,
                                        destinationAddress: String,
                                        date: Date,
                                        changeAddress: String = .unknown,
                                        transactionHash: String,
                                        transactionParams: TransactionParams? = nil) {
        if transactions.contains(where: { $0.hash == transactionHash }) {
            return
        }
        
        if addresses.all.contains(where: { $0.address.value == sourceAddress }) &&
            addresses.all.contains(where: { $0.address.value == destinationAddress }) {
            return
        }
        
        var tx = Transaction(amount: amount,
                             fee: Fee(fee),
                             sourceAddress: sourceAddress,
                             destinationAddress: destinationAddress,
                             changeAddress: changeAddress,
                             date: date,
                             hash: transactionHash)
        tx.params = transactionParams
        transactions.append(tx)
    }
    
    mutating func addPendingTransaction(_ tx: PendingTransaction) {
        addPendingTransaction(amount: Amount(with: blockchain, value: tx.value),
                              fee: Amount(with: blockchain, value: tx.fee ?? 0),
                              sourceAddress: tx.source,
                              destinationAddress: tx.destination,
                              date: tx.date,
                              transactionHash: tx.hash,
                              transactionParams: tx.transactionParams)
    }
    
    mutating func addDummyPendingTransaction() {
        let dummyAmount = Amount.dummyCoin(for: blockchain)
        var tx = Transaction(amount: dummyAmount,
                             fee: Fee(dummyAmount),
                             sourceAddress: .unknown,
                             destinationAddress: address,
                             changeAddress: .unknown)
        tx.date = Date()
        transactions.append(tx)
    }
    
    mutating func setTransactionHistoryList(_ transactions: [Transaction]) {
        self.transactions = transactions
    }
    
    mutating func remove(token: Token) {
        amounts[.token(value: token)] = nil
    }
}

extension Wallet {
    public struct PublicKey: Codable, Hashable {
        public let seedKey: Data
        public let derivation: Derivation

        public enum Derivation: Codable, Hashable {
            case not
            case derivation(path: DerivationPath, derivedKey: ExtendedPublicKey)
        }
        
        public var derivedKey: ExtendedPublicKey? {
            switch derivation {
            case .not:
                return nil
            case .derivation(_, let derivedKey):
                return derivedKey
            }
        }
        
        public var derivationPath: DerivationPath? {
            switch derivation {
            case .not:
                return nil
            case .derivation(let path, _):
                return path
            }
        }

        /// Derived or non-derived key that should be used to create an address in a blockchain
        public var blockchainKey: Data {
            switch derivation {
            case .not:
                return seedKey
            case .derivation(_, let derivedKey):
                return derivedKey.publicKey
            }
        }
        
        public init(seedKey: Data, derivation: Derivation) {
            self.seedKey = seedKey
            self.derivation = derivation
        }
    }
    
    public struct Addresses {
        public let `default`: WalletAddress
        public let legacy: WalletAddress?
        
        public var all: [WalletAddress] {
            [`default`, legacy].compactMap { $0 }
        }
    }
}
