#source 'https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git'
#source 'https://github.com/EnterTech/PodSpecs.git'

platform :ios, '11.0'
use_frameworks!
 
target 'BLETool' do

    pod 'FixedDFUService', '~> 4.11.2'
    pod 'SnapKit'
    pod 'SVProgressHUD'
#    pod 'RxSwift'
    pod 'RxCocoa'
    pod 'SwiftyTimer'
    pod 'Files'
    pod 'NaptimeFileProtocol', :git => "https://github.com/EnterTech/Naptime-FileProtocol-iOS.git", :branch => "develop"
#    pod 'PromiseKit'
#    pod 'RxBluetoothKit', :git => 'https://github.com/i-mobility/RxBluetoothKit.git', :tag => '7.0.2'
end

target 'NaptimeBLE' do
#    pod 'PromiseKit'
#    pod 'RxBluetoothKit', :git => 'https://github.com/i-mobility/RxBluetoothKit.git', :tag => '7.0.2'
end

post_install do |installer|
      installer.pods_project.build_configurations.each do |config|
        config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
      end
end
