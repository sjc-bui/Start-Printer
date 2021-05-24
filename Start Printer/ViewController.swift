//
//  ViewController.swift
//  Start Printer
//
//  Created by quan bui on 2021/05/21.
//

import UIKit
import QBIndicatorButton

class ViewController: UIViewController {

    @IBOutlet weak var printerBtn: QBIndicatorButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        printerBtn.animatedScale = 0.95
        printerBtn.touch({ btn in
            btn.start {
                self.printSample()
                btn.stop {
                    print(prettyLog())
                }
            }
        }, for: .touchUpInside)
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

    @objc func printSample() {
        let portName = searchPrinter()

        guard let portName = portName else {
            print("Port Name not found!")
            return
        }

        let commands = createHoldPrintData()
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

                var total: UInt32 = 0
                while total < UInt32(commands.count) {
                    var written: UInt32 = 0
                    try port.write(writeBuffer: commandsArray, offset: total, size: UInt32(commands.count) - total, numberOfBytesWritten: &written)
                    total += written
                }
                if total < UInt32(commands.count) {
                    break
                }

                try port.beginCheckedBlock(starPrinterStatus: &printerStatus, level: 2)

                if (printerStatus.offline == sm_true) {
                    print("printer offline.")
                    break
                }

                print("print success!")
                break
            } catch let error as NSError {
                print(error)
                break
            }
        }
    }

    func createHoldPrintData() -> Data {

        let builder: ISCBBuilder = StarIoExt.createCommandBuilder(StarIoExtEmulation.starLine)

        builder.beginDocument()

        builder.append(SCBCodePageType.CP932)

        builder.append(SCBInternationalType.japan)

        builder.appendCharacterSpace(0)

        builder.appendAlignment(SCBAlignmentPosition.center)

        builder.appendEmphasis(true)

        builder.appendData(withMultipleHeight: "スター電機\n".data(using: String.Encoding.shiftJIS), height: 3)

        builder.appendData(withMultipleHeight: "修理報告書　兼領収書\n".data(using: String.Encoding.shiftJIS), height: 2)

        builder.appendEmphasis(false)

        builder.appendAlignment(SCBAlignmentPosition.left)

        builder.append((
            "------------------------------------------------\n" +
            "発行日時：YYYY年MM月DD日HH時MM分\n" +
            "TEL：054-347-XXXX\n" +
            "\n" +
            "           ｲｹﾆｼ  ｼｽﾞｺ   ｻﾏ\n" +
            "　お名前：池西　静子　様\n" +
            "　御住所：静岡市清水区七ツ新屋\n" +
            "　　　　　５３６番地\n" +
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
            "技術料　          　　  1      150,000\n" +
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
//
//        builder.appendUnitFeed(32)
//        let otherDataUpcE: Data = "0123455".data(using: String.Encoding.ascii)!
//        builder.append("*0123455*\n".data(using: String.Encoding.ascii))
//        builder.appendBarcodeData(otherDataUpcE, symbology: SCBBarcodeSymbology.code39, width: SCBBarcodeWidth.mode1, height: 40, hri: true)

        let link: Data = "https://www.star-m.jp/".data(using: String.Encoding.ascii)!
        builder.appendUnitFeed(12)

        //builder.append("**Star HomePage**\n".data(using: String.Encoding.ascii))
        builder.appendQrCodeData(link, model: SCBQrCodeModel.no2, level: SCBQrCodeLevel.Q, cell: 10)

        builder.appendCutPaper(SCBCutPaperAction.partialCutWithFeed)

        builder.endDocument()

        return builder.commands.copy() as! Data
    }
}
