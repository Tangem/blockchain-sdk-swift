//
//  PolkadotWalletManager.swift
//  BlockchainSdk
//
//  Created by Andrey Chukavin on 01.02.2022.
//  Copyright © 2022 Tangem AG. All rights reserved.
//

import Foundation
import Combine
import CryptoKit
import TangemSdk
import BigInt
import web3swift

class PolkadotWalletManager: BaseManager, WalletManager {
    private let network: PolkadotNetwork
    var txBuilder: PolkadotTransactionBuilder!
    var networkService: PolkadotNetworkService!
    
    var currentHost: String { network.url.hostOrUnknown }
    
    init(network: PolkadotNetwork, wallet: Wallet) {
        self.network = network
        super.init(wallet: wallet)
    }
    
    func update(completion: @escaping (Result<(), Error>) -> Void) {
        cancellable = networkService.getInfo(for: wallet.address)
            .sink {
                switch $0 {
                case .failure(let error):
                    completion(.failure(error))
                case .finished:
                    completion(.success(()))
                }
            } receiveValue: { [unowned self] in
                self.updateInfo($0)
            }
    }
    
    private func updateInfo(_ balance: BigUInt) {
        let blockchain = network.blockchain
        let decimals = blockchain.decimalCount
        guard
            let formatted = Web3.Utils.formatToPrecision(balance, numberDecimals: decimals, formattingDecimals: decimals, decimalSeparator: ".", fallbackToScientific: false),
            let value = Decimal(formatted)
        else {
            return
        }
        
        wallet.add(amount: .init(with: blockchain, value: value))
        
        let currentDate = Date()
        for (index, transaction) in wallet.transactions.enumerated() {
            if let date = transaction.date,
               DateInterval(start: date, end: currentDate).duration > 10
            {
                wallet.transactions[index].status = .confirmed
            }
        }
    }
}

extension PolkadotWalletManager: TransactionSender {
    var allowsFeeSelection: Bool {
        false
    }
    
    func send(_ transaction: Transaction, signer: TransactionSigner) -> AnyPublisher<Void, Error> {
        networkService
            .blockchainMeta(for: transaction.sourceAddress)
            .flatMap { [weak self] meta -> AnyPublisher<Data, Error> in
                guard let self = self else {
                    return .emptyFail
                }
                return self.sign(amount: transaction.amount, destination: transaction.destinationAddress, meta: meta, signer: signer)
            }
            .flatMap { [weak self] image -> AnyPublisher<String, Error> in
                guard let self = self else {
                    return .emptyFail
                }
                return self.networkService.submitExtrinsic(data: image)
                    .mapError { SendTxError(error: $0, tx: image.hexString) }
                    .eraseToAnyPublisher()
            }
            .tryMap { [weak self] transactionID in
                var submittedTransaction = transaction
                submittedTransaction.hash = transactionID
                self?.wallet.transactions.append(submittedTransaction)
            }
            .eraseToAnyPublisher()
    }
    
    func getFee(amount: Amount, destination: String) -> AnyPublisher<[Amount], Error> {
        let blockchain = wallet.blockchain
        return networkService.blockchainMeta(for: destination)
            .flatMap { [weak self] meta -> AnyPublisher<Data, Error> in
                guard let self = self else {
                    return .emptyFail
                }
                return self.sign(amount: amount, destination: destination, meta: meta, signer: Ed25519DummyTransactionSigner())
            }
            .flatMap { [weak self] image -> AnyPublisher<UInt64, Error> in
                guard let self = self else {
                    return .emptyFail
                }
                return self.networkService.fee(for: image)
            }
            .map { intValue in
                [Amount(with: blockchain, value: Decimal(intValue) / blockchain.decimalValue)]
            }
            .eraseToAnyPublisher()
    }
    
    private func sign(amount: Amount, destination: String, meta: PolkadotBlockchainMeta, signer: TransactionSigner) -> AnyPublisher<Data, Error> {
        let wallet = self.wallet
        return Just(())
            .tryMap { [weak self] _ in
                guard let self = self else {
                    throw WalletError.empty
                }
                return try self.txBuilder.buildForSign(
                    amount: amount,
                    destination: destination,
                    meta: meta
                )
            }
            .flatMap { preImage in
                signer.sign(
                    hash: preImage,
                    walletPublicKey: wallet.publicKey
                )
            }
            .tryMap { [weak self] signature in
                guard let self = self else {
                    throw WalletError.empty
                }
                return try self.txBuilder.buildForSend(
                    amount: amount,
                    destination: destination,
                    meta: meta,
                    signature: signature
                )
            }
            .eraseToAnyPublisher()
    }
}

extension PolkadotWalletManager: WithdrawalValidator {
    func validate(_ transaction: Transaction) -> WithdrawalWarning? {
        guard let currentWalletAmount = wallet.amounts[.coin] else {
            return nil
        }
        
        let existentialDeposit = network.existentialDeposit
        let predictedWalletAmount = currentWalletAmount - transaction.amount - transaction.fee
        
        if predictedWalletAmount < existentialDeposit {
            let networkName = network.blockchain.displayName
            let amountToReduceBy = existentialDeposit - predictedWalletAmount
            return WithdrawalWarning(
                warningMessage: String(format: "dot_existential_deposit_message_warning".localized, networkName, existentialDeposit.description, amountToReduceBy.description),
                reduceMessage: String(format: "dot_existential_deposit_message_reduce".localized, amountToReduceBy.description),
                ignoreMessage: "dot_existential_deposit_message_ignore".localized,
                suggestedReduceAmount: amountToReduceBy
            )
        }
        return nil
    }
}

extension PolkadotWalletManager: ThenProcessable { }


// MARK: - Dummy transaction signer

fileprivate class Ed25519DummyTransactionSigner: TransactionSigner {
    private let privateKey = Data(repeating: 0, count: 32)
    
    func sign(hashes: [Data], walletPublicKey: Wallet.PublicKey) -> AnyPublisher<[Data], Error> {
        Fail(error: WalletError.failedToGetFee).eraseToAnyPublisher()
    }
    
    func sign(hash: Data, walletPublicKey: Wallet.PublicKey) -> AnyPublisher<Data, Error> {
        Just<Data>(hash)
            .tryMap { hash in
                try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey).signature(for: hash)
            }
            .eraseToAnyPublisher()
    }
}
