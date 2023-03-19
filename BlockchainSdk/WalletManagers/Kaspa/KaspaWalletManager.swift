//
//  KaspaWalletManager.swift
//  BlockchainSdk
//
//  Created by Andrey Chukavin on 10.03.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import Combine

class KaspaWalletManager: BaseManager, WalletManager {
    var txBuilder: KaspaTransactionBuilder!
    var networkService: KaspaNetworkService!
    
    var currentHost: String { networkService.host }
    var allowsFeeSelection: Bool { false }
    
    func update(completion: @escaping (Result<Void, Error>) -> Void) {
        cancellable = networkService.getInfo(address: wallet.address)
            .sink { result in
                switch result {
                case .failure(let error):
                    self.wallet.clearAmounts()
                    completion(.failure(error))
                case .finished:
                    completion(.success(()))
                }
            } receiveValue: { [weak self] response in
                self?.updateWallet(response)
            }
    }
    
    func send(_ transaction: Transaction, signer: TransactionSigner) -> AnyPublisher<TransactionSendResult, Error> {
        let kaspaTransaction: KaspaTransaction
        let hashes: [Data]
        
        do {
            let result = try txBuilder.buildForSign(transaction)
            kaspaTransaction = result.0
            hashes = result.1
        } catch {
            return .anyFail(error: error)
        }
        
        return signer.sign(hashes: hashes, walletPublicKey: wallet.publicKey)
            .tryMap { [weak self] signatures in
                guard let self = self else { throw WalletError.empty }
                
                return self.txBuilder.buildForSend(transaction: kaspaTransaction, signatures: signatures)
            }
            .flatMap { [weak self] tx -> AnyPublisher<KaspaTransactionResponse, Error> in
                guard let self = self else { return .emptyFail }
                
                return self.networkService.send(transaction: KaspaTransactionRequest(transaction: tx))
            }
            .map {
                TransactionSendResult(hash: $0.transactionId)
            }
            .eraseToAnyPublisher()
    }
    
    func getFee(amount: Amount, destination: String) -> AnyPublisher<[Amount], Error> {
        let numberOfUtxos = txBuilder.unspentOutputsCount(for: amount)
        guard numberOfUtxos > 0 else {
            return Fail(error: WalletError.failedToGetFee)
                .eraseToAnyPublisher()
        }
        
        let feePerUtxo = 10_000
        let fee = feePerUtxo * numberOfUtxos
        
        return Just([Amount(with: wallet.blockchain, value: Decimal(fee) / wallet.blockchain.decimalValue)])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    private func updateWallet(_ response: BitcoinResponse) {
        self.wallet.add(amount: Amount(with: self.wallet.blockchain, value: response.balance))
        txBuilder.setUnspentOutputs(response.unspentOutputs)
    }
}

extension KaspaWalletManager: ThenProcessable { }
