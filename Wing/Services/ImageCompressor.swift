//
//  ImageCompressor.swift
//  Wing
//
//  Created on 2026-01-29.
//

import UIKit

/**
 * 图片压缩工具
 *
 * 职责：
 * 1. 等比缩放图片到目标尺寸
 * 2. 压缩 JPEG 质量直到满足大小限制
 * 3. 线程安全（使用 actor）
 */
actor ImageCompressor {
    
    /**
     * 压缩图片到目标大小
     *
     * @param data 原始图片数据
     * @param maxSizeKB 最大文件大小（KB），默认 500KB
     * @param maxDimension 最大边长（像素），默认 2000px
     * @return 压缩后的 JPEG 数据，失败返回 nil
     */
    func compress(
        _ data: Data,
        maxSizeKB: Int = 500,
        maxDimension: CGFloat = 2000
    ) async -> Data? {
        guard let image = UIImage(data: data) else {
            return nil
        }
        
        // 1. 等比缩放到最大边长（在主线程执行）
        let scaledImage = await image.scaled(toMaxDimension: maxDimension)
        
        // 2. 二分法压缩质量直到满足大小
        var quality: CGFloat = 0.9
        var result = scaledImage.jpegData(compressionQuality: quality)
        
        let targetSize = maxSizeKB * 1024
        
        while let currentData = result,
              currentData.count > targetSize,
              quality > 0.1 {
            quality -= 0.1
            result = scaledImage.jpegData(compressionQuality: quality)
        }
        
        return result
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /**
     * 等比缩放图片到最大边长
     *
     * @param maxDimension 最大边长（像素）
     * @return 缩放后的图片
     */
    @MainActor
    func scaled(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let size = self.size
        
        // 如果已经小于目标尺寸，直接返回
        if size.width <= maxDimension && size.height <= maxDimension {
            return self
        }
        
        // 计算缩放比例
        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }
        
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        // 使用 UIGraphicsImageRenderer 进行高质量缩放
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
