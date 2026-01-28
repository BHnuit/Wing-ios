//
//  KeychainHelperTests.swift
//  WingTests
//
//  Created on 2026-01-29.
//

import Testing
import Foundation
@testable import Wing

@Suite("KeychainHelper Tests")
struct KeychainHelperTests {
    
    let helper = KeychainHelper.shared
    
    @Test("Save and Load String")
    func testSaveAndLoadString() async throws {
        let key = "test_api_key_1"
        let value = "sk-1234567890abcdef"
        
        // Clean up before test
        try await helper.delete(key)
        
        // Save
        try await helper.save(value, for: key)
        
        // Load
        let loadedValue = try await helper.loadString(for: key)
        
        #expect(loadedValue == value)
        
        // Clean up
        try await helper.delete(key)
    }
    
    @Test("Update Existing Key")
    func testUpdateKey() async throws {
        let key = "test_api_key_update"
        let initialValue = "initial_value"
        let updatedValue = "updated_value"
        
        // Clean up before test
        try await helper.delete(key)
        
        // Initial Save
        try await helper.save(initialValue, for: key)
        let loadedInitial = try await helper.loadString(for: key)
        #expect(loadedInitial == initialValue)
        
        // Update
        try await helper.save(updatedValue, for: key)
        let loadedUpdated = try await helper.loadString(for: key)
        #expect(loadedUpdated == updatedValue)
        
        // Clean up
        try await helper.delete(key)
    }
    
    @Test("Delete Key")
    func testDeleteKey() async throws {
        let key = "test_api_key_delete"
        let value = "to_be_deleted"
        
        // Save
        try await helper.save(value, for: key)
        var loaded = try await helper.loadString(for: key)
        #expect(loaded != nil)
        
        // Delete
        try await helper.delete(key)
        
        // Verify deletion
        loaded = try await helper.loadString(for: key)
        #expect(loaded == nil)
    }
    
    @Test("Concurrency Safety")
    func testConcurrency() async throws {
        let keyBase = "test_concurrency_"
        
        // Define a task group to perform concurrent saves
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let key = "\(keyBase)\(i)"
                    let value = "value_\(i)"
                    try await helper.save(value, for: key)
                    let loaded = try await helper.loadString(for: key)
                    #expect(loaded == value)
                    try await helper.delete(key)
                }
            }
            // Wait for all tasks to complete
            try await group.waitForAll()
        }
    }
}
