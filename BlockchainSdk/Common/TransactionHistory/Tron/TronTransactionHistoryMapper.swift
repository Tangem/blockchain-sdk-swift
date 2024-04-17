//
//  TronTransactionHistoryMapper.swift
//  BlockchainSdk
//
//  Created by Andrey Fedorov on 21.11.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import TangemSdk

struct TronTransactionHistoryMapper {
    private let blockchain: Blockchain

    init(blockchain: Blockchain) {
        self.blockchain = blockchain
    }

    private func extractTransactions(
        from response: BlockBookAddressResponse,
        amountType: Amount.AmountType
    ) -> [BlockBookAddressResponse.Transaction] {
        guard let transactions = response.transactions else {
            return []
        }

        switch amountType {
        case .coin, .reserve:
            return transactions
        case .token(let value):
            // Another fix for a horrible Tron Blockbook API: sometimes API returns transaction history 
            // from another token for a particular token if this token doesn't have transaction history yet
            //
            // Here we're filtering out unrelated transaction history completely if needed
            guard
                let tokens = response.tokens,
                tokens.contains(where: { $0.matching(contractAddress: value.contractAddress) })
            else {
                return []
            }

            return transactions
        }
    }

    /// Extracts the transaction info for a `coin` transfer.
    private func extractTransactionInfo(
        from transaction: BlockBookAddressResponse.Transaction,
        sourceAddress: String,
        destinationAddress: String,
        walletAddress: String
    ) -> TransactionInfo? {
        guard
            sourceAddress.caseInsensitiveEquals(to: walletAddress) || destinationAddress.caseInsensitiveEquals(to: walletAddress)
        else {
            Log.log("Unrelated transaction \(transaction) received")
            return nil
        }

        guard let transactionValue = Decimal(string: transaction.value) else {
            Log.log("Transaction with invalid value \(transaction) received")
            return nil
        }

        let transactionAmount = transactionValue / blockchain.decimalValue
        let isOutgoing = sourceAddress.caseInsensitiveEquals(to: walletAddress)

        let source = TransactionRecord.Source(
            address: sourceAddress,
            amount: transactionAmount
        )

        let destination = TransactionRecord.Destination(
            address: transaction.isContractInteraction ? .contract(destinationAddress) : .user(destinationAddress),
            amount: transactionAmount
        )

        return TransactionInfo(
            source: source,
            destination: destination,
            isOutgoing: isOutgoing
        )
    }

    /// Extracts the transaction info for a `token` transfer.
    private func extractTransactionInfos(
        from tokenTransfers: [BlockBookAddressResponse.TokenTransfer],
        token: Token,
        walletAddress: String,
        isOutgoing: Bool
    ) -> [TransactionInfo] {
        // Double check to exclude token transfers sent to self.
        // Actually, this is a feasible case, but we don't support such transfers at the moment
        let filteredTokenTransfers = tokenTransfers.filter { transfer in
            if isOutgoing {
                return transfer.from.caseInsensitiveEquals(to: walletAddress) && !transfer.to.caseInsensitiveEquals(to: walletAddress)
            }
            return transfer.to.caseInsensitiveEquals(to: walletAddress) && !transfer.from.caseInsensitiveEquals(to: walletAddress)
        }

        let otherAddresses: [String]
        let groupedFilteredTokenTransfers: [String: [BlockBookAddressResponse.TokenTransfer]]

        if isOutgoing {
            otherAddresses = filteredTokenTransfers.uniqueProperties(\.to)
            groupedFilteredTokenTransfers = filteredTokenTransfers.grouped(by: \.to)
        } else {
            otherAddresses = filteredTokenTransfers.uniqueProperties(\.from)
            groupedFilteredTokenTransfers = filteredTokenTransfers.grouped(by: \.from)
        }

        return otherAddresses.reduce(into: []) { partialResult, otherAddress in
            let transfers = groupedFilteredTokenTransfers[otherAddress, default: []]

            partialResult += transfers.compactMap { transfer in
                guard
                    let rawValue = transfer.value,
                    let value = Decimal(string: rawValue)
                else {
                    Log.log("Token transfer \(transfer) with invalid value received")
                    return nil
                }

                let transactionAmount = value / token.decimalValue

                let source = TransactionRecord.Source(
                    address: isOutgoing ? walletAddress : otherAddress,
                    amount: transactionAmount
                )

                let destination = TransactionRecord.Destination(
                    address: .user(isOutgoing ? otherAddress : walletAddress),
                    amount: transactionAmount
                )

                return TransactionInfo(
                    source: source,
                    destination: destination,
                    isOutgoing: isOutgoing
                )
            }
        }
    }

    private func mapToTransactionRecords(
        transaction: BlockBookAddressResponse.Transaction,
        transactionInfos: [TransactionInfo],
        amountType: Amount.AmountType,
        fees: Decimal
    ) -> [TransactionRecord] {
        // Nownodes appends `0x` prefixes to TRON txids, so we have to strip these prefixes
        let hash = transaction.txid.removeHexPrefix()
        let fee = Fee(Amount(with: blockchain, value: fees / blockchain.decimalValue))
        let date = Date(timeIntervalSince1970: TimeInterval(transaction.blockTime))
        let status = status(transaction)
        let type = transactionType(transaction, amountType: amountType)
        let tokenTransfers = tokenTransfers(transaction)

        return transactionInfos.map { transactionInfo in
            return TransactionRecord(
                hash: hash,
                index: 0,   // TODO: Andrey Fedorov - Add support for indexed transactions (IOS-6340)
                source: .single(transactionInfo.source),
                destination: .single(transactionInfo.destination),
                fee: fee,
                status: status,
                isOutgoing: transactionInfo.isOutgoing,
                type: type,
                date: date,
                tokenTransfers: tokenTransfers
            )
        }
    }

    private func status(_ transaction: BlockBookAddressResponse.Transaction) -> TransactionRecord.TransactionStatus {
        switch transaction.tronTXReceipt?.status {
        case .failure:
            return .failed
        case .ok:
            return .confirmed
        case .pending:
            return .unconfirmed
        case .none:
            return transaction.confirmations > 0 ? .confirmed : .unconfirmed
        }
    }

    private func transactionType(
        _ transaction: BlockBookAddressResponse.Transaction,
        amountType: Amount.AmountType
    ) -> TransactionRecord.TransactionType {
        switch amountType {
        case .coin where transaction.isContractInteraction:
            return .contractMethodName(name: transaction.contractName ?? "")
        case .coin, .reserve, .token:
            // All TRC10 and TRC20 token transactions are considered simple & plain transfers
            return .transfer
        }
    }

    private func tokenTransfers(_ transaction: BlockBookAddressResponse.Transaction) -> [TransactionRecord.TokenTransfer]? {
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

// MARK: - BlockBookTransactionHistoryMapper protocol conformance

extension TronTransactionHistoryMapper: BlockBookTransactionHistoryMapper {
    func mapToTransactionRecords(
        _ response: BlockBookAddressResponse,
        amountType: Amount.AmountType
    ) -> [TransactionRecord] {
        let transactions = extractTransactions(from: response, amountType: amountType)
        let walletAddress = response.address

        return transactions
            .reduce(into: []) { partialResult, transaction in
                guard
                    let sourceAddress = transaction.fromAddress,
                    let destinationAddress = transaction.toAddress,
                    let fees = Decimal(transaction.fees)
                else {
                    Log.log("Transaction \(transaction) doesn't contain a required information")
                    return
                }

                switch amountType {
                case .coin, .reserve:
                    if let transactionInfo = extractTransactionInfo(
                        from: transaction,
                        sourceAddress: sourceAddress,
                        destinationAddress: destinationAddress,
                        walletAddress: walletAddress
                    ) {
                        partialResult += mapToTransactionRecords(
                            transaction: transaction,
                            transactionInfos: [transactionInfo],
                            amountType: amountType,
                            fees: fees
                        )
                    }
                case .token(let token):
                    if let transfers = transaction.tokenTransfers, !transfers.isEmpty {
                        let outgoingTransactionInfos = extractTransactionInfos(
                            from: transfers,
                            token: token,
                            walletAddress: walletAddress,
                            isOutgoing: true
                        )
                        let incomingTransactionInfos = extractTransactionInfos(
                            from: transfers,
                            token: token,
                            walletAddress: walletAddress,
                            isOutgoing: false
                        )
                        partialResult += mapToTransactionRecords(
                            transaction: transaction,
                            transactionInfos: outgoingTransactionInfos + incomingTransactionInfos,
                            amountType: amountType,
                            fees: fees
                        )
                    }
                }
            }
    }
}

// MARK: - BlockBookTransactionHistoryTotalPageCountExtractor protocol conformance

extension TronTransactionHistoryMapper: BlockBookTransactionHistoryTotalPageCountExtractor {
    func extractTotalPageCount(from response: BlockBookAddressResponse, contractAddress: String?) throws -> Int {
        // If transaction history is requested for a TRC20 token - `totalPageCount` must be calculated manually
        // using `$.tokens[*].transfers` and `$.itemsOnPage` DTO fields because `$.totalPages` DTO field always
        // contains the number of pages for the TRX (Tron coin) transaction history for a given address
        //
        // If there is no transaction history for a particular TRC20 token - the `response.tokens` field 
        // does not exist or is empty; in such cases we consider the transaction history empty (`totalPageCount` equals 0)
        if let contractAddress {
            guard
                let itemsOnPage = response.itemsOnPage,
                let tokens = response.tokens,
                let token = tokens.first(where: { $0.matching(contractAddress: contractAddress) }),
                let transfersCount = token.transfers
            else {
                return 0
            }

            return Int(ceil((Double(transfersCount) / Double(itemsOnPage))))
        }

        return response.totalPages ?? 0
    }
}

// MARK: - Convenience types

private extension TronTransactionHistoryMapper {
    /// Intermediate model for simpler mapping.
    struct TransactionInfo {
        let source: TransactionRecord.Source
        let destination: TransactionRecord.Destination
        let isOutgoing: Bool
    }

    /// See https://github.com/tronprotocol/documentation/blob/master/English_Documentation/TRON_Virtual_Machine/TRC10_TRX_TRANSFER_INTRODUCTION_FOR_EXCHANGES.md
    /// and https://github.com/tronprotocol/protocol/blob/master/English%20version%20of%20TRON%20Protocol%20document.md for reference
    /// - Note: Only a small subset of existing contact types are represented in this enum.
    enum TronContractType: Int {
        /// Tron transfers.
        case transferContractType = 1
        /// TRC10 token transfers.
        case transferAssetContractType = 2
        /// TRC20 token transfers.
        case triggerSmartContract = 31
    }
}

// MARK: - Convenience extensions

private extension BlockBookAddressResponse.Token {
    func matching(contractAddress: String) -> Bool {
        // Tron Blockbook has a really terrible API contract: a token's contract address may be stored in various DTO fields,
        // not just in the `$.tokens[*].contract` field
        let props = [
            id,
            name,
            contract,
        ]

        return props
            .compactMap { $0?.caseInsensitiveEquals(to: contractAddress) }
            .contains(true)
    }
}

private extension BlockBookAddressResponse.Transaction {
    var isContractInteraction: Bool {
        return contractType != nil
        && contractType != TronTransactionHistoryMapper.TronContractType.transferContractType.rawValue
    }
}
