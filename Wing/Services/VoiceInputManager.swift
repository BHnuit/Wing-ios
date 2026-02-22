//
//  VoiceInputManager.swift
//  Wing
//
//  Created on 2026-02-16.
//

import Foundation
import Speech
import AVFoundation
import os

@Observable
@MainActor
class VoiceInputManager: NSObject, SFSpeechRecognizerDelegate {
    var isRecording = false
    var recognizedText = ""
    var error: String?
    var permissionGranted = false
    
    private static let logger = Logger(subsystem: "wing", category: "VoiceInput")
    
    // 延迟初始化：避免在 ComposerView 创建时就访问音频硬件
    private var _speechRecognizer: SFSpeechRecognizer?
    private var speechRecognizerReady = false
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var _audioEngine: AVAudioEngine?
    
    private var speechRecognizer: SFSpeechRecognizer? {
        if !speechRecognizerReady {
            _speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
            _speechRecognizer?.delegate = self
            speechRecognizerReady = true
        }
        return _speechRecognizer
    }
    
    private var audioEngine: AVAudioEngine {
        if _audioEngine == nil {
            _audioEngine = AVAudioEngine()
        }
        return _audioEngine!
    }
    
    override init() {
        super.init()
        // 同步检查既有权限状态，如果已经授权，不要让用户点两次
        if SFSpeechRecognizer.authorizationStatus() == .authorized && AVAudioApplication.shared.recordPermission == .granted {
            self.permissionGranted = true
        }
    }
    
    // MARK: - Permissions
    
    // nonisolated 避免 SFSpeechRecognizer 的后台回调误触发 MainActor 断言
    nonisolated private static func requestSpeechAuth() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    @discardableResult
    func checkPermissions() async -> Bool {
        // 1. 请求语音识别权限
        let speechStatus = await Self.requestSpeechAuth()
        
        guard speechStatus == .authorized else {
            permissionGranted = false
            error = "语音识别权限未授权"
            Self.logger.warning("Speech recognition not authorized: \(String(describing: speechStatus))")
            return false
        }
        
        // 2. 请求麦克风权限
        let micGranted = await AVAudioApplication.requestRecordPermission()
        
        if micGranted {
            permissionGranted = true
            Self.logger.info("All voice permissions granted")
            return true
        } else {
            permissionGranted = false
            error = "麦克风权限未授权"
            Self.logger.warning("Microphone permission denied")
            return false
        }
    }
    
    func startRecording() {
        guard permissionGranted else {
            Task {
                await checkPermissions()
            }
            return
        }
        
        // Reset state
        recognizedText = ""
        error = nil
        
        // Cancel existing task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            Self.logger.error("无法激活音频会话: \(error)")
            self.error = "无法激活音频会话"
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        // 为了防止 Swift 6 向下继承 @MainActor 导致在音频后台线程被调用时 _dispatch_assert_queue_fail 崩溃
        // 我们需要使用 nonisolated 的方式去挂载这两个闭包
        let inputNode = audioEngine.inputNode
        
        let weakManager = WeakManager(value: self)
        recognitionTask = Self.setupRecognitionTask(
            recognizer: speechRecognizer,
            request: recognitionRequest,
            managerProxy: weakManager
        )
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        Self.setupAudioTap(on: inputNode, format: recordingFormat, request: recognitionRequest)

        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            Self.logger.error("无法启动音频引擎: \(error)")
            self.error = "无法启动音频引擎"
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
    
    // MARK: - Nonisolated Helpers
    // 通过彻底剥离 MainActor 上下文，防止闭包内被编译器插入 dispatch_assert_queue(main) 引起 brk #0x1 崩溃
    
    // 专为穿透隔离域的弱引用封装
    struct WeakManager: @unchecked Sendable {
        weak var value: VoiceInputManager?
    }
    
    nonisolated private static func setupRecognitionTask(
        recognizer: SFSpeechRecognizer?,
        request: SFSpeechAudioBufferRecognitionRequest,
        managerProxy: WeakManager
    ) -> SFSpeechRecognitionTask? {
        return recognizer?.recognitionTask(with: request) { result, error in
            let transcription = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let hasError = (error != nil)
            
            Task { @MainActor in
                guard let manager = managerProxy.value else { return }
                
                if let text = transcription {
                    manager.recognizedText = text
                }
                
                if hasError || isFinal {
                    manager.stopRecording()
                }
            }
        }
    }
    
    nonisolated private static func setupAudioTap(
        on node: AVAudioInputNode,
        format: AVAudioFormat,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }
}
