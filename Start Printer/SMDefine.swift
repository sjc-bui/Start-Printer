//
//  SMDefine.swift
//  Start Printer
//
//  Created by quan bui on 2021/05/24.
//

import Foundation

let sm_true:  UInt32 = 1
let sm_false: UInt32 = 0

func prettyLog(_ filePath: String = #file,
               line: Int = #line,
               funcName: String = #function) -> String {
    let fileName: String = filePath.components(separatedBy: "/").last!
    return "\(fileName): \(line) - \(funcName)"
}
