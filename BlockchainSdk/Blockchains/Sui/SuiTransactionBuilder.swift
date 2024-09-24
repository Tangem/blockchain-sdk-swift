//
// SuiTransactionBuilder.swift
// BlockchainSdk
//
// Created by Sergei Iakovlev on 30.08.2024
// Copyright © 2024 Tangem AG. All rights reserved.
//

import Foundation
import WalletCore
import TangemSdk

class SuiTransactionBuilder {
    private let signer: any Address
    private let publicKey: Wallet.PublicKey
    private let decimalValue: Decimal
    private var coins: [SuiCoinObject] = []
    
    init(publicKey: Wallet.PublicKey, decimalValue: Decimal) throws {
        self.signer = try WalletCoreAddressService(coin: .sui).makeAddress(for: publicKey, with: .default)
        self.publicKey = publicKey
        self.decimalValue = decimalValue
    }
    
    func update(coins: [SuiCoinObject]) {
        self.coins = coins
    }
    
    func buildForInspect(amount: Amount, destination: String, referenceGasPrice: Decimal) throws -> String {
        let useCoins = coins
        let totalAmount = coins.reduce(into: Decimal(0)) { partialResult, coin in
            partialResult += coin.balance
        }
        
        var decimalAmount = amount.value * decimalValue
        let isSendMax = decimalAmount == totalAmount
        
        let budget = min(totalAmount - Decimal(1), SUIUtils.SuiGasBudgetMaxValue)
        let inputAmount = isSendMax ? totalAmount - budget : decimalAmount
        
        let input = try input(amount: inputAmount / decimalValue, destination: destination, fee: .init(gasPrice: referenceGasPrice, gasBudget: budget))
        
        let signatureMock = Data(repeating: 0x01, count: 64)
        
        let compiled = try TransactionCompiler.compileWithSignatures(coinType: .sui,
                                                                     txInputData: input.serializedData(),
                                                                     signatures: signatureMock.asDataVector(),
                                                                     publicKeys: publicKey.blockchainKey.asDataVector())
        let output = try SuiSigningOutput(serializedData: compiled)
        
        return output.unsignedTx
    }
    
    func buildForSign(transaction: Transaction) throws -> Data {
        guard let suiFeeParameters = transaction.fee.parameters as? SuiFeeParameters else {
            throw WalletError.failedToBuildTx
        }
        
        let input = try input(amount: transaction.amount.value, destination: transaction.destinationAddress, fee: suiFeeParameters)
        
        let preImageHashes = try TransactionCompiler.preImageHashes(coinType: .sui, txInputData: input.serializedData())
        let preSigningOutput = try TxCompilerPreSigningOutput(serializedData: preImageHashes)
        
        if preSigningOutput.error != .ok {
            Log.debug("SuiPreSigningOutput has a error: \(preSigningOutput.errorMessage)")
            throw WalletError.failedToBuildTx
        }
        
        return preSigningOutput.dataHash
        
    }
    
    func buildForSend(transaction: Transaction, signature: Data) throws -> (txBytes: String, signature: String) {
        guard let suiFeeParameters = transaction.fee.parameters as? SuiFeeParameters else {
            throw WalletError.failedToBuildTx
        }
        
        let input = try input(amount: transaction.amount.value, destination: transaction.destinationAddress, fee: suiFeeParameters)
        
        let compiled = try TransactionCompiler.compileWithSignaturesAndPubKeyType(coinType: .sui,
                                                                                  txInputData: input.serializedData(),
                                                                                  signatures: signature.asDataVector(),
                                                                                  publicKeys: publicKey.blockchainKey.asDataVector(),
                                                                                  pubKeyType: .ed25519)
        
        let output = try SuiSigningOutput(serializedData: compiled)
        return (output.unsignedTx, output.signature)
    }
    
    private func input(amount: Decimal, destination: String, fee: SuiFeeParameters) throws -> WalletCore.SuiSigningInput {
        let decimalAmount = amount * decimalValue
        let useCoins = getCoins(for: decimalAmount + fee.gasBudget)

        return WalletCore.SuiSigningInput.with { input in
            let inputCoins = useCoins.map { coin in
                SuiObjectRef.with({ coins in
                    coins.version = coin.version
                    coins.objectID = coin.coinObjectId
                    coins.objectDigest = coin.digest
                })
            }
            
            input.paySui = WalletCore.SuiPaySui.with({ pay in
                pay.inputCoins = inputCoins
                pay.recipients = [destination]
                pay.amounts = [decimalAmount.uint64Value]
            })
            
            input.signer = signer.value
            input.gasBudget = fee.gasBudget.uint64Value
            input.referenceGasPrice = fee.gasPrice.uint64Value
        }
    }
    
    private func getCoins(for amount: Decimal) -> [SuiCoinObject] {
        var inputs: [SuiCoinObject] = []
        var total: Decimal = 0
        
        for coin in coins {
            inputs.append(coin)
            total += coin.balance
            
            if total >= amount {
                break
            }
        }
        
        return inputs
    }
}
