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

      let address = "愛知県名古屋市中区大須１丁目２１"

      getLoc(from: address) { coor in
          var success: Bool = false

          let lat = coor?.latitude
          let long = coor?.longitude

          let commands = self.createHoldPrintData(address: address, lat: lat ?? 0, long: long ?? 0)
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
                  break
              } catch let error as NSError {
                  print(error)
                  success = false
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

      builder.appendData(withMultipleHeight: "領収書\n".data(using: String.Encoding.shiftJIS), height: 2)

      builder.appendEmphasis(false)

      builder.appendAlignment(SCBAlignmentPosition.left)

      builder.append((
      "half-width chars = 48\n" +
      "var width: [Int] = [14, 11, 22]\n" +
      "------------------------------------------------\n" +
      "1 フライポテト\n" +
      "  ソース\n" +
      "  ふりかけ(+50円)\n" +
      "------------------------------------------------\n" +
      printText(price: 15610, quantity: 2, width: width)    +
      printText(price: 190000, quantity: 1, width: width)    +
      printText(price: 999990, quantity: 1, width: width)    +
      printText(price: 99, quantity: 111, width: width)    +
      printText(price: 1, quantity: 11111, width: width)    +
      "　    \\190,000         2点              \\380,000\n" +
      "　 \\999990,000  22222222点      \\219,219,780,000\n" +
      "　         \\99       211点               \\20,889\n" +
      "　          \\1        19点                   \\19\n" +
      "================================================\n" +
      "\n").data(using: String.Encoding.shiftJIS))

      builder.appendAlignment(SCBAlignmentPosition.center)

//      if lat != 0 && long != 0 {
//          let link = "https://maps.google.com/?q=@\(lat),\(long)"
//          let qrlink: Data = link.data(using: String.Encoding.ascii)!
//          builder.appendUnitFeed(12)
//          builder.appendQrCodeData(qrlink, model: SCBQrCodeModel.no2, level: SCBQrCodeLevel.Q, cell: 10)
//      }

      builder.appendCutPaper(SCBCutPaperAction.partialCutWithFeed)

      builder.endDocument()

      return builder.commands.copy() as! Data
  }

  func numFormat(num: Int, type: Type) -> String {
    switch type {
      case .price:
        return "\\\(num.delimiter)"
      case .quantity:
        return "\(num.delimiter)点"
    }
  }

  var width: [Int] = [14, 11, 22]
  func printText(price: Int, quantity: Int, width: [Int]) -> String {
    let priceStr = numFormat(num: price, type: .price)
    let quantityStr = numFormat(num: quantity, type: .quantity)
    let totalStr = numFormat(num: (price * quantity), type: .price)

    let firstCol  = repeatElement(" ", count: width[0] - priceStr.count) + "\(priceStr)"
    let secondCol = repeatElement(" ", count: width[1] - quantityStr.count) + "\(quantityStr)"
    let thirdCol  = repeatElement(" ", count: width[2] - totalStr.count) + "\(totalStr)"
    return "\(firstCol)\(secondCol)\(thirdCol)\n"
  }
}

enum Type {
  case price
  case quantity
}

extension Int {
  private static var numFormatter: NumberFormatter = {
    let numFormatter = NumberFormatter()
    numFormatter.numberStyle = .decimal
    return numFormatter
  }()

  var delimiter: String {
    return Int.numFormatter.string(from: NSNumber(value: self))!
  }
}
