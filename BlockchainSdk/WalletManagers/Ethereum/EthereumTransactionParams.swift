//
//  EthereumTransactionParams.swift
//  BlockchainSdk
//
//  Created by Andrew Son on 12/04/21.
//

import Foundation
import BigInt

public struct EthereumTransactionParams: TransactionParams {
    public let data: Data
    public let gasLimit: BigUInt?
    public let gasPrice: BigUInt?
    public let nonce: Int?
    
    public init(data: Data, gasLimit: Int? = nil, gasPrice: Int? = nil, nonce: Int? = nil) {
        self.data = data
        self.gasLimit = gasLimit == nil ? nil : BigUInt(gasLimit!)
        self.gasPrice = gasPrice == nil ? nil : BigUInt(gasPrice!)
        self.nonce = nonce
    }
}
