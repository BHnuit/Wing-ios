//
//  VoiceInputManager.swift
//  Wing
//
//  Created on 2026-02-16.
//

import Foundation
import Speech
import AVFoundation

@Observable
@MainActor
class VoiceInputManager: NSObject, SFSpeechRecognizerDelegate {
    var isRecording = false
    var recognizedText = ""
    var error: String?
    var permissionGranted = false
    
    // ... (rest is fine, but methods are now MainActor isolated)
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
        checkPermissions()
    }
    
    func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            Task { @MainActor in
                guard let self = self else { return }
                switch authStatus {
                case .authorized:
                    self.permissionGranted = true
                default:
                    self.permissionGranted = false
                    self.error = "语音识别权限未授权"
                }
            }
        }
    }
    
    // ... (toggleRecording is fine on MainActor)
    
    func startRecording() {
        guard permissionGranted else {
            checkPermissions()
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
            self.error = "无法激活音频会话"
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        // Access inputNode (requires engine to be not running? safe to access)
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            // This callback might not be on main thread
            Task { @MainActor in
                guard let self = self else { return }
                
                var isFinal = false
                
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                    isFinal = result.isFinal
                }
                
                if error != nil || isFinal {
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    self.isRecording = false
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            error = nil
        } catch {
            self.error = "无法启动音频引擎"
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
    }
}
