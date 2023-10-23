//
//  NEARNetworkProvider.swift
//  BlockchainSdk
//
//  Created by Andrey Fedorov on 13.10.2023.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Foundation
import Combine

struct NEARNetworkProvider {
    private let baseURL: URL

    init(
        baseURL: URL,
        configuration: NetworkProviderConfiguration
    ) {
        self.baseURL = baseURL
    }
}

// MARK: - HostProvider protocol conformance

extension NEARNetworkProvider: HostProvider {
    var host: String {
        baseURL.hostOrUnknown
    }
}
