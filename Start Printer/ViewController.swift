//
//  ViewController.swift
//  Start Printer
//
//  Created by quan bui on 2021/05/21.
//

import UIKit
import QBIndicatorButton
import CoreLocation

class ViewController: UIViewController {

    @IBOutlet weak var printerBtn: QBIndicatorButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        printerBtn.animatedScale = 0.95
        printerBtn.touch({ btn in
            btn.start { [weak self] in
                guard let self = self else { return }
                self.printSample {
                    btn.stop {
                        print("🟢 Success!")
                    }
                } failureCompletion: {
                    btn.stop {
                        print("❌ Error appear, please try again!")
                    }
                }

            }
        }, for: .touchUpInside)
    }

    func getLoc(from address: String, completion: @escaping (_ loc: CLLocationCoordinate2D?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, err in
            guard let placemarks = placemarks,
                  let location = placemarks.first?.location?.coordinate else {
                completion(nil)
                return
            }
            completion(location)
        }
    }

    func searchPrinter() -> String? {
        var searchPrinterResult: [PortInfo]? = nil

        do {
            searchPrinterResult = try SMPort.searchPrinter(target: "BT:") as? [PortInfo]
        } catch {
            print("Error!")
        }

        guard let portArray: [PortInfo] = searchPrinterResult else {
            return ""
        }

        for portInfo: PortInfo in portArray {
            print("Port Name: \(portInfo.portName ?? "")")
            print("MAC Address: \(portInfo.macAddress ?? "")")
            print("Model Name: \(portInfo.modelName ?? "")")
        }

        return portArray.first?.portName
    }

    private func printSample(successCompletion: (() -> Void)?, failureCompletion: (() -> Void)?) {
        let portName = searchPrinter()

        guard let portName = portName else {
            print("Port Name not found!")
            return
        }

        let address = "愛知県名古屋市中区栄２丁目３−１ 名古屋広小路ビルヂング 11F"

        getLoc(from: address) { coor in
            var success: Bool = false

            let lat = coor?.latitude
            let long = coor?.longitude

            guard lat != 0,
                  long != 0 else { return }

            let commands = self.createHoldPrintData(address: address, lat: lat!, long: long!)
            var commandsArray: [UInt8] = [UInt8](repeating: 0, count: commands.count)
            commands.copyBytes(to: &commandsArray, count: commands.count)

            while true {
                var port: SMPort

                do {
                    port = try SMPort.getPort(portName: portName, portSettings: "", ioTimeoutMillis: 10000)

                    defer {
                        SMPort.release(port)
                    }

                    var printerStatus: StarPrinterStatus_2 = StarPrinterStatus_2()

                    try port.beginCheckedBlock(starPrinterStatus: &printerStatus, level: 2)

                    if (printerStatus.offline == sm_true) {
                        print("printer offline.")
                        break
                    }

                    let startDate: Date = Date()

                    var total: UInt32 = 0

                    while total < UInt32(commands.count) {
                        var written: UInt32 = 0
                        try port.write(writeBuffer: commandsArray, offset: total, size: UInt32(commands.count) - total, numberOfBytesWritten: &written)
                        total += written

                        if Date().timeIntervalSince(startDate) >= 30.0 {
                            break
                        }
                    }
                    if total < UInt32(commands.count) {
                        break
                    }

                    try port.endCheckedBlock(starPrinterStatus: &printerStatus, level: 2)

                    if (printerStatus.offline == sm_true) {
                        print("printer offline.")
                        break
                    }

                    success = true
                    self.msg(message: "print success!")
                    break
                } catch let error as NSError {
                    print(error)
                    success = false
                    self.msg(message: "\(error)")
                    break
                }
            }

            if success {
                successCompletion?()
            } else {
                failureCompletion?()
            }
        }
    }

    func msg(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
    }

    func createHoldPrintData(address: String, lat: CLLocationDegrees, long: CLLocationDegrees) -> Data {

        let builder: ISCBBuilder = StarIoExt.createCommandBuilder(StarIoExtEmulation.starLine)

        builder.beginDocument()

        builder.append(SCBCodePageType.CP932)

        builder.append(SCBInternationalType.japan)

        builder.appendCharacterSpace(0)

        builder.appendAlignment(SCBAlignmentPosition.center)

        builder.appendEmphasis(true)

        builder.appendData(withMultipleHeight: "東京\n".data(using: String.Encoding.shiftJIS), height: 2)

        builder.appendData(withMultipleHeight: "小平市\n".data(using: String.Encoding.shiftJIS), height: 2)

        builder.appendEmphasis(false)

        builder.appendAlignment(SCBAlignmentPosition.left)

        builder.append((
            "------------------------------------------------\n" +
            "発行日時：YYYY年MM月DD日HH時MM分\n" +
            "TEL：054-347-XXXX\n" +
            "\n" +
            "           **   ｻﾏ\n" +
            "　お名前：**　様\n" +
            "　御住所：\(address)\n" +
            "　伝票番号：No.12345-67890\n" +
            "\n" +
            "　この度は修理をご用命頂き有難うございます。\n" +
            " 今後も故障など発生した場合はお気軽にご連絡ください。\n" +
            "\n" +
            "品名／型名　          数量      金額　   備考\n" +
            "------------------------------------------------\n" +
            "制御基板　          　  1      10,000     配達\n" +
            "操作スイッチ            1       3,800     配達\n" +
            "パネル　　          　  1       2,000     配達\n" +
            "技術料　          　　  1     150,000\n" +
            "出張費用　　            1       5,000\n" +
            "------------------------------------------------\n" +
            "\n" +
            "                            小計       \\ 35,800\n" +
            "                            内税       \\  1,790\n" +
            "                            合計       \\ 37,590\n" +
            "\n" +
            "　お問合わせ番号　　12345-67890\n" +
            "\n").data(using: String.Encoding.shiftJIS))

        builder.appendAlignment(SCBAlignmentPosition.center)

        let link = "https://maps.google.com/?q=@\(lat),\(long)"
        let qrlink: Data = link.data(using: String.Encoding.ascii)!
        builder.appendUnitFeed(12)

        builder.appendQrCodeData(qrlink, model: SCBQrCodeModel.no2, level: SCBQrCodeLevel.Q, cell: 10)

        builder.appendCutPaper(SCBCutPaperAction.partialCutWithFeed)

        builder.endDocument()

        return builder.commands.copy() as! Data
    }
}
