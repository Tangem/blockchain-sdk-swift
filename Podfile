platform :ios, '13.0'
use_frameworks!
inhibit_all_warnings!

def common_pods
  pod 'TangemSdk', :git => 'https://github.com/Tangem/tangem-sdk-ios.git', :tag => 'develop-198'
  #pod 'TangemSdk', :path => '../tangem-sdk-ios'
  
  pod 'BitcoinCore.swift', :git => 'https://github.com/tangem/bitcoincore.git', :tag => '0.0.16'
  # pod 'BitcoinCore.swift', :path => '../bitcoincore'
end


target 'BlockchainSdk' do
  pod 'BigInt'
  pod 'SwiftyJSON'
  pod 'Alamofire'
  pod 'Moya'
  pod 'Sodium'
  pod 'SwiftCBOR'
  pod 'BinanceChain', :git => 'https://github.com/tangem/swiftbinancechain.git', :tag => '0.0.9'
  #pod 'BinanceChain', :path => '../SwiftBinanceChain'
  pod 'HDWalletKit', :git => 'https://github.com/tangem/hdwallet.git', :tag => '0.3.12'
  #pod 'HDWalletKit', :path => '../HDWallet'
  #pod 'web3swift', :path => '../web3swift'
  pod 'web3swift', :git => 'https://github.com/tangem/web3swift.git', :tag => '2.2.10'
  pod 'AnyCodable-FlightSchool'
  pod 'stellar-ios-mac-sdk'
  
  pod 'Solana.Swift', :git => 'https://github.com/tangem/Solana.Swift', :tag => 'add-external-signer-7'
#  pod 'Solana.Swift', :path => '../Solana.Swift'
  pod 'ScaleCodec'
  pod 'SwiftProtobuf'
  
  common_pods
end

target 'BlockchainSdkTests' do
  common_pods
end

target 'BlockchainSdkExample' do
  pod 'Sodium'
end

post_install do |installer|

  installer.pods_project.build_configurations.each do |config|
      if config.name.include?("Debug")
          config.build_settings['GCC_OPTIMIZATION_LEVEL'] = '0'
          config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
          config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
          config.build_settings['ENABLE_TESTABILITY'] = 'YES'
          config.build_settings['SWIFT_COMPILATION_MODE'] = 'Incremental'
      end

      config.build_settings['DEAD_CODE_STRIPPING'] = 'YES'
  end


  installer.pods_project.targets.each do |target|

    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end

    if target.respond_to?(:product_type) and target.product_type == "com.apple.product-type.bundle"
      target.build_configurations.each do |config|
        config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      end
    end

  end
end
