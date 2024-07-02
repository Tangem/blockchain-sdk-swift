//
//  KoinosDTOMapper.swift
//  BlockchainSdk
//
//  Created by Aleksei Muraveinik on 30.06.24.
//

import Foundation

enum KoinosDTOMapper {
    static func convertResourceLimitData(_ dto: KoinosMethod.GetResourceLimits.Response) throws -> KoinosResourceLimitData {
        let limits = dto.resourceLimitData
        
        guard let diskStorageLimit = UInt64(limits.diskStorageLimit),
              let diskStorageCost = UInt64(limits.diskStorageCost),
              let networkBandwidthLimit = UInt64(limits.networkBandwidthLimit),
              let networkBandwidthCost = UInt64(limits.networkBandwidthCost),
              let computeBandwidthLimit = UInt64(limits.computeBandwidthLimit),
              let computeBandwidthCost = UInt64(limits.computeBandwidthCost)
        else {
            throw KoinosDTOMapperError.failedToMapKoinosDTO
        }
        
        return KoinosResourceLimitData(
            diskStorageLimit: diskStorageLimit,
            diskStorageCost: diskStorageCost,
            networkBandwidthLimit: networkBandwidthLimit,
            networkBandwidthCost: networkBandwidthCost,
            computeBandwidthLimit: computeBandwidthLimit,
            computeBandwidthCost: computeBandwidthCost
        )
    }
    
    static func convertKoinBalance(_ dto: KoinosMethod.ReadContract.Response) throws -> UInt64 {
        guard let result = dto.result, let decodedResult = result.base64URLDecodedData() else {
            return 0
        }
        return try Koinos_Contracts_Token_balance_of_result(serializedData: decodedResult).value
    }
    
    static func convertAccountRC(_ dto: KoinosMethod.GetAccountRC.Response) -> UInt64 {
        guard let stringRC = dto.rc, let rc = UInt64(stringRC) else {
            return 0
        }
        return rc
    }
    
    static func convertNonce(_ dto: KoinosMethod.GetAccountNonce.Response) throws -> KoinosAccountNonce {
        let base64EncodedNonce = dto.nonce
        
        guard let data = base64EncodedNonce.base64URLDecodedData() else {
            throw KoinosDTOMapperError.failedToMapKoinosDTO
        }
        
        let type = try Koinos_Chain_value_type(serializedData: data)
        return KoinosAccountNonce(nonce: type.uint64Value)
    }
    
    static func convertTransactionEntry(_ dto: KoinosProtocol.TransactionReceipt) throws -> KoinosTransactionEntry {
        guard let maxPayerRc = UInt64(dto.maxPayerRc),
              let rcUsed = UInt64(dto.rcUsed),
              let encodedEvent = dto.events.first?.data,
              let data = encodedEvent.base64URLDecodedData()
        else {
            throw KoinosDTOMapperError.failedToMapKoinosDTO
        }
        
        let decodedEvent = try Koinos_Contracts_Token_transfer_event(serializedData: data)
        
        return KoinosTransactionEntry(
            id: dto.id,
            sequenceNum: UInt64.max,
            payerAddress: dto.payer,
            rcLimit: maxPayerRc,
            rcUsed: rcUsed,
            event: KoinosTransferEvent(
                fromAccount: decodedEvent.from.base58EncodedString,
                toAccount: decodedEvent.to.base58EncodedString,
                value: decodedEvent.value
            )
        )
    }
}

enum KoinosDTOMapperError: Error {
    case failedToMapKoinosDTO
}
