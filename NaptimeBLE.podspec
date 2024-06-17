Pod::Spec.new do |s|
  s.name             = 'NaptimeBLE'
  s.version          = '1.1.0'
  s.summary          = 'Naptime BLE 通信库'
  s.description      = <<-DESC
Naptime BLE 通信库
                       DESC

  s.homepage         = 'https://github.com/EnterTech'
  s.author           = { 'HyanCat' => 'hyancat@live.cn' }
  s.license          = 'LICENSE'
  s.source           = { :git => 'git@github.com:EnterTech/Naptime-BLE-iOS.git', :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'

  s.source_files = 'NaptimeBLE/**/*.swift'
  s.dependency 'PromiseKit'
  s.dependency 'RxBluetoothKit_Airthings'

end