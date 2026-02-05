//
//  Extensions.swift
//  Wing
//
//  Created on 2026-02-05.
//

import Foundation

extension String {
    /// 计算 Levenshtein 编辑距离
    nonisolated func levenshteinDistance(to destination: String) -> Int {
        let source = Array(self)
        let dest = Array(destination)
        
        let sourceCount = source.count
        let destCount = dest.count
        
        guard sourceCount > 0 else { return destCount }
        guard destCount > 0 else { return sourceCount }
        
        var matrix = Array(repeating: Array(repeating: 0, count: destCount + 1), count: sourceCount + 1)
        
        for i in 0...sourceCount {
            matrix[i][0] = i
        }
        
        for j in 0...destCount {
            matrix[0][j] = j
        }
        
        for i in 1...sourceCount {
            for j in 1...destCount {
                let cost = source[i - 1] == dest[j - 1] ? 0 : 1
                matrix[i][j] = Swift.min(
                    matrix[i - 1][j] + 1,      // 删除
                    matrix[i][j - 1] + 1,      // 插入
                    matrix[i - 1][j - 1] + cost // 替换
                )
            }
        }
        
        return matrix[sourceCount][destCount]
    }
    
    /// 计算字符串相似度 (0.0 - 1.0)
    /// 基于 Levenshtein 距离
    nonisolated func similarity(to other: String) -> Double {
        let maxLen = max(self.count, other.count)
        if maxLen == 0 { return 1.0 }
        
        let distance = self.levenshteinDistance(to: other)
        return 1.0 - (Double(distance) / Double(maxLen))
    }
}
