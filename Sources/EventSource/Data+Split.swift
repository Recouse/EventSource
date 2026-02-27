//
//  Data+Split.swift
//  EventSource
//
//  Created by JadianZheng on 2025/7/24.
//

import Foundation

extension Data {
    func split(separators: [[UInt8]]) -> (completeData: [Data], remainingData: Data) {
        var currentIndex = startIndex
        var messages = [Data]()
        
        while currentIndex < endIndex {
            var foundSeparator: [UInt8]? = nil
            var foundRange: Range<Data.Index>? = nil
            
            let remainingData = self[currentIndex..<endIndex]
            
            for separator in separators {
                if let range = remainingData.firstRange(of: separator) {
                    
                    if foundRange == nil || range.lowerBound < foundRange!.lowerBound {
                        foundSeparator = separator
                        foundRange = range
                    }
                }
            }
            
            if let separator = foundSeparator, let range = foundRange {
                let messageData = self[currentIndex..<range.lowerBound]
                
                if !messageData.isEmpty {
                    messages.append(Data(messageData))
                }
                
                currentIndex = range.upperBound
            } else {
                break
            }
        }
        
        let remainingData = currentIndex < endIndex ? self[currentIndex..<endIndex] : Data()
        return (messages, Data(remainingData))
    }
}
