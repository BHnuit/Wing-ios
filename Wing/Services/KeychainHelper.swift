//
//  KeychainHelper.swift
//  Wing
//
//  Created on 2026-01-29.
//

import Foundation
import Security

// MARK: - KeychainError

/**
 * Keychain 操作错误枚举
 */
enum KeychainError: Error, LocalizedError {
    case duplicateEntry
    case unknown(OSStatus)
    case itemNotFound
    case invalidItemFormat
    case unexpectedStatus(OSStatus)
    case unhandledError(message: String)

    var errorDescription: String? {
        switch self {
        case .duplicateEntry:
            return "Item already exists in Keychain."
        case .unknown(let status):
            return "System error with status code: \(status)"
        case .itemNotFound:
            return "Item not found in Keychain."
        case .invalidItemFormat:
            return "Invalid item format retrieved from Keychain."
        case .unexpectedStatus(let status):
            return "Unexpected status code: \(status)"
        case .unhandledError(let message):
            return "Unhandled error: \(message)"
        }
    }
}

// MARK: - KeychainHelper

/**
 * 安全存储服务
 * 使用系统 Keychain 存储敏感信息（如 API Key）。
 * 作为一个全局 Actor，确保并发安全。
 */
@globalActor
actor KeychainHelper {
    
    static let shared = KeychainHelper()
    
    private let serviceName = "com.wing.app.service"
    
    private init() {}
    
    // MARK: - Core Methods (Data)
    
    /**
     * 保存数据到 Keychain
     * 如果 Key 已存在，则更新数据。
     *
     * - Parameters:
     *   - data: 要保存的二进制数据
     *   - key: 唯一标识符 (Account)
     */
    func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: serviceName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // 尝试添加
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // 如果已存在，则更新
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: serviceName
            ]
            
            let attributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unknown(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unknown(status)
        }
    }
    
    /**
     * 从 Keychain 读取数据
     *
     * - Parameter key: 唯一标识符 (Account)
     * - Returns: 存储的数据，如果不存在则返回 nil
     */
    func load(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            guard let data = dataTypeRef as? Data else {
                throw KeychainError.invalidItemFormat
            }
            return data
        } else if status == errSecItemNotFound {
            return nil
        } else {
            throw KeychainError.unknown(status)
        }
    }
    
    /**
     * 从 Keychain 删除数据
     *
     * - Parameter key: 唯一标识符 (Account)
     */
    func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // 删除不存在的项不算错误
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unknown(status)
        }
    }
    
    // MARK: - Helper Methods (String)
    
    /**
     * 保存字符串到 Keychain (UTF-8)
     */
    func save(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.unhandledError(message: "Failed to convert string to UTF-8 data")
        }
        try save(data, for: key)
    }
    
    /**
     * 从 Keychain 读取字符串
     */
    func loadString(for key: String) throws -> String? {
        guard let data = try load(for: key) else {
            return nil
        }
        
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidItemFormat
        }
        
        return string
    }
}
