//
//  EthereumTransactionHistoryMapper.swift
//  BlockchainSdk
//
//  Created by Sergey Balashov on 26.07.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import TangemSdk

struct EthereumTransactionHistoryMapper {
    private let blockchain: Blockchain
    
    private var decimalValue: Decimal {
        blockchain.decimalValue
    }
    
    init(blockchain: Blockchain) {
        self.blockchain = blockchain
    }
}

// MARK: - TransactionHistoryMapper protocol conformance

extension EthereumTransactionHistoryMapper: TransactionHistoryMapper {
    func mapToTransactionRecords(
        _ response: BlockBookAddressResponse,
        walletAddress: String,
        amountType: Amount.AmountType
    ) throws -> [TransactionRecord] {
        guard let transactions = response.transactions else {
            return []
        }
        
        return transactions.compactMap { transaction -> TransactionRecord? in
            guard
                let source = source(transaction, walletAddress: response.address, amountType: amountType),
                let destination = destination(transaction, walletAddress: response.address, amountType: amountType),
                let feeWei = Decimal(transaction.fees)
            else {
                Log.log("BlockBookAddressResponse.Transaction \(transaction) doesn't contain a required information")
                return nil
            }
            
            let fee = Fee(Amount(with: blockchain, value: feeWei / decimalValue))
            
            return TransactionRecord(
                hash: transaction.txid,
                index: 0,   // TODO: Andrey Fedorov - Add support for indexed transactions (IOS-6340)
                source: .single(source),
                destination: .single(destination),
                fee: fee,
                status: status(transaction),
                isOutgoing: isOutgoing(transaction, walletAddress: response.address, amountType: amountType),
                type: transactionType(transaction),
                date: Date(timeIntervalSince1970: TimeInterval(transaction.blockTime)),
                tokenTransfers: tokenTransfers(transaction)
            )
        }
    }
}

// MARK: - Private

private extension EthereumTransactionHistoryMapper {
    func status(_ transaction: BlockBookAddressResponse.Transaction) -> TransactionRecord.TransactionStatus {
        guard let status = transaction.ethereumSpecific?.status else {
            return transaction.confirmations > 0 ? .confirmed : .unconfirmed
        }
        
        switch status {
        case .failure:
            return .failed
        case .ok:
            return .confirmed
        case .pending:
            return .unconfirmed
        }
    }

    /// Determines the direction of tokens transfer from a given transaction for a given address and token pair.
    ///
    /// - Note: Currently, we don't support and therefore can't parse and display multiple transfers of the same token
    /// to/from the same address in a single transaction.
    /// Because of that, the direction of token transfer may be determined incorrectly in such cases.
    /// Consider adding such support (refactoring will likely be required).
    func isOutgoing(
        _ transaction: BlockBookAddressResponse.Transaction,
        walletAddress: String,
        amountType: Amount.AmountType
    ) -> Bool {
        switch amountType {
        case .coin, .reserve, .feeResource:
            return transaction.compat.vin.first?.addresses.first == walletAddress
        case .token(let token):
            if transaction.tokenTransfers == nil {
                Log.log("""
                Unable to determine the direction of a tokens transfer in transaction \(transaction) \
                due to missing tokens transfers field
                """)
            }

            let allTokenTransfers = transaction.tokenTransfers ?? []
            let filteredTokenTransfers = allTokenTransfers.filter { transfer in
                guard let contract = transfer.compat.contract else {
                    return false
                }

                return token.contractAddress.caseInsensitiveEquals(to: contract)
            }

            if filteredTokenTransfers.isEmpty {
                Log.log("""
                Unable to determine the direction of a tokens transfer in transaction \(transaction) \
                due to empty tokens transfers array
                """)
            }

            return filteredTokenTransfers.contains { $0.from == walletAddress }
        }
    }

    /// Build information about exactly one tokens transfer from a given transaction for a given address and token pair.
    ///
    /// - Note: Currently, we don't support and therefore can't parse and display multiple transfers of the same token
    /// to/from the same address in a single transaction.
    /// Consider adding such support (refactoring will likely be required).
    func tokensTransferInfo(
        from transaction: BlockBookAddressResponse.Transaction,
        walletAddress: String,
        amountType: Amount.AmountType
    ) -> (transfer: BlockBookAddressResponse.TokenTransfer, isOutgoing: Bool)? {
        guard let token = amountType.token else {
            Log.log("Incorrect amount type \(amountType) for transaction \(transaction)")
            return nil
        }

        let isOutgoing = isOutgoing(transaction, walletAddress: walletAddress, amountType: amountType)
        let allTokenTransfers = transaction.tokenTransfers ?? []

        let filteredTokenTransfers = allTokenTransfers.filter { transfer in
            guard let contract = transfer.compat.contract else {
                return false
            }

            return token.contractAddress.caseInsensitiveEquals(to: contract)
        }

        if filteredTokenTransfers.count == 1 {
            return (filteredTokenTransfers[0], isOutgoing)
        }

        // In the case of multiple token transfers to and from different addresses within a single EVM transaction,
        // we have to find a single token transfer that was made by us
        return filteredTokenTransfers
            .first { transfer in
                let otherAddress = isOutgoing ? transfer.from : transfer.to
                return walletAddress.caseInsensitiveEquals(to: otherAddress)
            }
            .map { ($0, isOutgoing) }
    }
    
    func source(
        _ transaction: BlockBookAddressResponse.Transaction,
        walletAddress: String,
        amountType: Amount.AmountType
    ) -> TransactionRecord.Source? {
        guard let vin = transaction.compat.vin.first, let address = vin.addresses.first else {
            Log.log("Source information in transaction \(transaction) not found")
            return nil
        }
        
        switch amountType {
        case .coin, .reserve, .feeResource:
            if let amount = Decimal(string: transaction.value) {
                return TransactionRecord.Source(address: address, amount: amount / decimalValue)
            }
        case .token:
            let info = tokensTransferInfo(from: transaction, walletAddress: walletAddress, amountType: amountType)
            if let transfer = info?.transfer, let amount = Decimal(transfer.value) {
                let decimalValue = pow(10, transfer.decimals)
                return TransactionRecord.Source(
                    address: address,
                    amount: amount / decimalValue
                )
            }
        }
        
        return nil
    }
    
    func destination(
        _ transaction: BlockBookAddressResponse.Transaction,
        walletAddress: String,
        amountType: Amount.AmountType
    ) -> TransactionRecord.Destination? {
        guard let vout = transaction.compat.vout.first, let address = vout.addresses.first else {
            Log.log("Destination information in transaction \(transaction) not found")
            return nil
        }

        switch amountType {
        case .coin, .reserve, .feeResource:
            if let amount = Decimal(string: transaction.value) {
                // We can receive a data only like "0x" and then we should delete this prefix
                let isContainsData = transaction.ethereumSpecific?.data?.removeHexPrefix().isEmpty == false
                let isContainsTokenTransfers = transaction.tokenTransfers?.isEmpty == false
                let isContract = isContainsData || isContainsTokenTransfers
                return TransactionRecord.Destination(
                    address: isContract ? .contract(address) : .user(address),
                    amount: amount / decimalValue
                )
            }
        case .token:
            let info = tokensTransferInfo(from: transaction, walletAddress: walletAddress, amountType: amountType)
            if let (transfer, isOutgoing) = info, let amount = Decimal(transfer.value) {
                let decimalValue = pow(10, transfer.decimals)
                return TransactionRecord.Destination(
                    address: isOutgoing ? .user(transfer.to) : .user(transfer.from),
                    amount: amount / decimalValue
                )
            }
        }
        
        return nil
    }
    
    func transactionType(_ transaction: BlockBookAddressResponse.Transaction) -> TransactionRecord.TransactionType {
        let ethereumSpecific = transaction.ethereumSpecific
        let methodId = ethereumSpecific?.parsedData?.methodId ?? methodIdFromRawData(ethereumSpecific?.data)

        guard let methodId = methodId else {
            return .transfer
        }
        
        // MethodId is empty for the coin transfers
        if methodId.isEmpty {
            return .transfer
        }
        
        return .contractMethodIdentifier(id: methodId)
    }
    
    private func methodIdFromRawData(_ rawData: String?) -> String? {
        // EVM method name has a length of 4 bytes
        let methodIdLength = 8

        guard
            let methodId = rawData?.stripHexPrefix().prefix(methodIdLength),
            methodId.count == methodIdLength
        else {
            return nil
        }

        return String(methodId).addHexPrefix()
    }
    
    func tokenTransfers(_ transaction: BlockBookAddressResponse.Transaction) -> [TransactionRecord.TokenTransfer]? {
        guard let tokenTransfers = transaction.tokenTransfers else {
            return nil
        }
        
        return tokenTransfers.map { transfer -> TransactionRecord.TokenTransfer in
            let amount = Decimal(transfer.value) ?? 0
            return TransactionRecord.TokenTransfer(
                source: transfer.from,
                destination: transfer.to,
                amount: amount,
                name: transfer.name,
                symbol: transfer.symbol,
                decimals: transfer.decimals,
                contract: transfer.compat.contract
            )
        }
    }
}
