//
//  Connector.swift
//  NaptimeBLE
//
//  Created by HyanCat on 03/11/2017.
//  Copyright © 2017 EnterTech. All rights reserved.
//

import Foundation
import CoreBluetooth
import RxBluetoothKit
import RxSwift
import PromiseKit

public protocol DisposeHolder {
    var disposeBag: DisposeBag { get }
}

extension RxBluetoothKit.Service: Hashable {
    public var hashValue: Int {
        return self.uuid.hash
    }
}

public final class Connector: DisposeHolder {

    public typealias ConnectResultBlock = ((Bool) -> Void)
    public let peripheral: Peripheral

    public private(set) var connectService: ConnectService?
    public private(set) var commandService: CommandService?
    public private(set) var eegService: EEGService?
    public private(set) var batteryService:  BatteryService?
    public private(set) var dfuService: DFUService?
    public private(set) var deviceInfoService: DeviceInfoService?

    public var allServices: [BLEService] {
        return ([connectService, commandService, eegService, batteryService, dfuService, deviceInfoService] as [BLEService?]).filter { $0 != nil } as! [BLEService]
    }

    private(set) var mac: Data?

    private (set) public var disposeBag: DisposeBag = DisposeBag()
    private var _disposable: Disposable?

    public init(peripheral: Peripheral) {
        self.peripheral = peripheral
    }

    public func tryConnect() -> Promise<Void> {
        let promise = Promise<Void> { (fulfill, reject) in
            _disposable = peripheral.connect()
                .flatMap {
                    $0.discoverServices(nil)
                }.flatMap {
                    Observable.from($0)
                }.`do`(onNext: { [weak self] in
                    print("uuid: \($0.uuid.uuidString)")
                    guard let `self` = self else { return }
                    guard let `type` = NaptimeBLE.ServiceType(rawValue: $0.uuid.uuidString) else { return }
                    switch `type` {
                    case .connect:
                        self.connectService = ConnectService(rxService: $0)
                    case .command:
                        self.commandService = CommandService(rxService: $0)
                    case .battery:
                        self.batteryService = BatteryService(rxService: $0)
                    case .eeg:
                        self.eegService = EEGService(rxService: $0)
                    case .dfu:
                        self.dfuService = DFUService(rxService: $0)
                    case .deviceInfo:
                        self.deviceInfoService = DeviceInfoService(rxService: $0)
                    }
                }).flatMap {
                    $0.discoverCharacteristics(nil)
                }.flatMap {
                    Observable.from($0)
                }.subscribe(onNext: { _ in
                    //
                }, onError: { error in
                    print("\(error)")
                    reject(error)
                }, onCompleted: {
                    guard self.commandService != nil && self.batteryService != nil && self.eegService != nil && self.dfuService != nil && self.deviceInfoService != nil else {
                        reject(BLEError.connectFail)
                        return
                    }
                    fulfill(())
                })
        }
        return promise
    }

    public func cancel() {
        _disposable?.dispose()
    }

    private var _stateListener: Disposable?
    private var _handshakeListener: Disposable?

    public func handshake(userID: UInt32 = 0) -> Promise<Void> {

        let promise = Promise<Void> { (fulfill, reject) in

            let disposeListener = { [weak self] in
                self?._stateListener?.dispose()
                self?._handshakeListener?.dispose()
            }
            // 监听状态
            _stateListener = self.connectService!.notify(characteristic: .state).subscribe(onNext: { bytes in
                print("state: \(bytes)")
                guard let state = HandshakeState(rawValue: bytes) else { return }

                switch state {
                case .success:
                    fulfill(())
                case .error(let err):
                    reject(err)
                }
                disposeListener()
            }, onError: { error in
                print("state error: \(error)")
                reject(error)
                disposeListener()
            })
            _stateListener?.disposed(by: disposeBag)

            Thread.sleep(forTimeInterval: 0.1)
            // 监听 第二步握手
            _handshakeListener = self.connectService!.notify(characteristic: .handshake).subscribe(onNext: { data in
                print("2------------ \(data)")
                var secondCommand = data
                let random = secondCommand.last!
                secondCommand.removeFirst()
                secondCommand.removeLast()
                let newRandom = UInt8(arc4random_uniform(255))
                secondCommand[0] = secondCommand[0] ^ random ^ newRandom
                secondCommand[1] = secondCommand[1] ^ random ^ newRandom
                secondCommand[2] = secondCommand[2] ^ random ^ newRandom
                secondCommand.insert(0x03, at: 0)
                secondCommand.append(newRandom)
                print("3------------ \(secondCommand)")
                // 发送 第三步握手
                self.connectService?.write(data: Data(bytes: secondCommand), to: .handshake)
                    .catch { error in
                    reject(error)
                }
            }, onError: { error in
                print("握手 error: \(error)")
                reject(error)
                disposeListener()
            })
            _handshakeListener?.disposed(by: disposeBag)

            // 开始握手
            Thread.sleep(forTimeInterval: 0.1)
            // 读取 mac 地址
            self.deviceInfoService!.read(characteristic: .mac)
                .then { data -> Promise<Void> in
                    self.mac = data
                    print("mac: \(data)")
                    // 发送 user id
                    let bytes = [0x00, userID >> 24, userID >> 16, userID >> 8, userID].map { $0 & 0xFF }.map { UInt8($0) }
                    return self.connectService!.write(data: Data(bytes: bytes), to: .userID)
                }
                .then { () -> (Promise<Void>) in
                    // 发送 第一步握手
                    let date = Date()
                    let hour = UInt8(date.stringWith(formateString: "HH"))
                    let minute = UInt8(date.stringWith(formateString: "mm"))
                    let second = UInt8(date.stringWith(formateString: "ss"))
                    let random = UInt8(arc4random_uniform(255))
                    print("1------------ \([0x01 ,hour! ,minute! ,second! ,random])")
                    return self.connectService!.write(data: Data(bytes: [0x01 ,hour! ,minute! ,second! ,random]), to: .handshake)
                }.catch { error in
                    print("握手 error: \(error)")
            }
        }
        return promise
    }
}

extension Date {
    public func stringWith(formateString: String)-> String {
        let dateFormate = DateFormatter()
        dateFormate.locale = Locale(identifier: "zh_CN")
        dateFormate.dateFormat = formateString
        return dateFormate.string(from: self)
    }
}
