//
//  CosmosTransactionBuilder.swift
//  BlockchainSdk
//
//  Created by Andrey Chukavin on 11.04.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import WalletCore

class CosmosTransactionBuilder {
    private let wallet: Wallet
    private let cosmosChain: CosmosChain
    private var sequenceNumber: UInt64?
    private var accountNumber: UInt64?
    
    init(wallet: Wallet, cosmosChain: CosmosChain) {
        self.wallet = wallet
        self.cosmosChain = cosmosChain
    }
    
    func setSequenceNumber(_ sequenceNumber: UInt64) {
        self.sequenceNumber = sequenceNumber
    }
    
    func setAccountNumber(_ accountNumber: UInt64) {
        self.accountNumber = accountNumber
    }
    
    func buildForSign(amount: Amount, source: String, destination: String, feeAmount: Decimal?, gas: UInt64?, params: CosmosTransactionParams?) throws -> CosmosSigningInput {
        let amountInSmallestDenomination = ((amount.value * cosmosChain.blockchain.decimalValue) as NSDecimalNumber).uint64Value
        
        let denomination = cosmosChain.smallestDenomination
        let sendCoinsMessage = CosmosMessage.Send.with {
            $0.fromAddress = source
            $0.toAddress = destination
            $0.amounts = [CosmosAmount.with {
                $0.amount = "\(amountInSmallestDenomination)"
                $0.denom = denomination
            }]
        }
        
        let message = CosmosMessage.with {
            $0.sendCoinsMessage = sendCoinsMessage
        }
        
        let fee: CosmosFee?
        if let feeAmount, let gas {
            var feeAmountInSmallestDenomination = (feeAmount * cosmosChain.blockchain.decimalValue as NSDecimalNumber).uint64Value
            
            if let tax = tax(for: amount) {
                feeAmountInSmallestDenomination += tax
            }
            
            fee = CosmosFee.with {
                $0.gas = gas
                $0.amounts = [CosmosAmount.with {
                    $0.amount = "\(feeAmountInSmallestDenomination)"
                    $0.denom = denomination
                }]
            }
        } else {
            fee = nil
        }
        
        guard
            let accountNumber = self.accountNumber,
            let sequenceNumber = self.sequenceNumber
        else {
            throw WalletError.failedToBuildTx
        }
        
        let input = CosmosSigningInput.with {
            $0.signingMode = .protobuf;
            $0.accountNumber = accountNumber
            $0.chainID = cosmosChain.chainID
            $0.memo = params?.memo ?? ""
            $0.sequence = sequenceNumber
            $0.messages = [message]
            if let fee = fee {
                $0.fee = fee
            }
            $0.privateKey = Data(repeating: 1, count: 32)
        }
        
        return input
    }
    
    func buildForSend(input: CosmosSigningInput, signer: TransactionSigner?) throws -> Data {
        let output: CosmosSigningOutput
        if let signer {
            let coreSigner = WalletCoreSigner(sdkSigner: signer, walletPublicKey: self.wallet.publicKey, curve: cosmosChain.blockchain.curve)
            output = AnySigner.signExternally(input: input, coin: cosmosChain.coin, signer: coreSigner)
        } else {
            output = AnySigner.sign(input: input, coin: cosmosChain.coin)
        }
        
        guard let outputData = output.serialized.data(using: .utf8) else {
            throw WalletError.failedToBuildTx
        }
        
        return outputData
    }
    
    private func tax(for amount: Amount) -> UInt64? {
        guard let taxPercent = cosmosChain.taxPercent else {
            return nil
        }
        
        let amountInSmallestDenomination = amount.value * cosmosChain.blockchain.decimalValue
        let taxAmount = amountInSmallestDenomination * taxPercent / 100
        
        return (taxAmount as NSDecimalNumber).uint64Value
    }
}
