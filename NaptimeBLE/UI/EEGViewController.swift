//
//  EEGViewController.swift
//  NaptimeBLE
//
//  Created by NyanCat on 27/10/2017.
//  Copyright © 2017 EnterTech. All rights reserved.
//

import UIKit
import CoreBluetooth
import RxBluetoothKit
import RxSwift
import SVProgressHUD
import SwiftyTimer

class EEGViewController: UIViewController {
    var service: Service!
    var characteristic: Characteristic?

    var isSampling: Bool = false
    private let disposeBag = DisposeBag()

    @IBOutlet weak var textView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "采集", style: .plain, target: self, action: #selector(sampleButtonTouched))

        service.discoverCharacteristics(nil)
            .flatMap { Observable.from($0) }
            .filter {
                ($0.uuid.whichCharacteristic == .eeg_data) || ($0.uuid.whichCharacteristic == .eeg_data_1)
            }
            .take(1)
            .subscribe(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.characteristic = $0
            }).disposed(by: disposeBag)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isSampling {
            self.sampleButtonTouched()
        }
    }

    @objc
    private func sampleButtonTouched() {
        if isSampling {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "采集", style: .plain, target: self, action: #selector(sampleButtonTouched))
            self.characteristic?.setNotifyValue(false).subscribe().disposed(by: disposeBag)
            _timer?.invalidate()
            _timer = nil
            let fileName = EEGFileManager.shared.fileName
            EEGFileManager.shared.close()
            SVProgressHUD.showSuccess(withStatus: "保存文件成功: \(fileName!)")
        } else {
            EEGFileManager.shared.create()
            self.textView.text.removeAll()
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "停止", style: .plain, target: self, action: #selector(sampleButtonTouched))
            let dataPool = DataPool()
            self.characteristic?.setNotificationAndMonitorUpdates().subscribe(onNext: {
                if let data = $0.value {
                    dataPool.push(data: data)
                }
            }, onError: { _ in
                SVProgressHUD.showError(withStatus: "发现特性失败")
            }).disposed(by: disposeBag)

            _timer = Timer.every(0.5, {
                if dataPool.isAvailable {
                    let data = dataPool.pop(length: 1000)
                    self.saveToFile(data: data)
                    dispatch_to_main {
                        self.updateTempToTextView(data: data)
                    }
                }
            })
        }
        isSampling = !isSampling
    }

    var _timer: Timer?

    private func updateTempToTextView(data: Data) {
        self.textView.text.append(data.hexString)
        self.textView.scrollRangeToVisible(NSMakeRange(self.textView.text.count-1, 1))
    }

    private func saveToFile(data: Data) {
        EEGFileManager.shared.save(data: data)
    }
}
