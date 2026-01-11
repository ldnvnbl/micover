import Foundation
import SwiftUI
import Shared

@Observable
@MainActor
final class AppState {
    // UI 状态
    var isFloatingWindowVisible = false
    var testMessage = ""
    var pingCount = 0
    
    // 录音统计（实时）
    var recordedPackets = 0
    var recordingStartTime: Date?
    
    // 今日统计（从存储加载）
    private(set) var todayStats: DailyStats = .today()
    
    // MARK: - Computed Properties
    
    var recordingCount: Int {
        todayStats.recordingCount
    }
    
    var totalRecordingDuration: Int {
        todayStats.totalRecordingDuration
    }
    
    var totalTranscribedWords: Int {
        todayStats.totalTranscribedWords
    }
    
    var smartPhraseTriggeredCount: Int {
        todayStats.smartPhraseTriggeredCount
    }
    
    /// 平均听写速度 (Words Per Minute)
    /// 计算公式: 总字数 / 总时长(分钟)
    var averageWPM: Double {
        guard totalRecordingDuration > 0 else { return 0 }
        let minutes = Double(totalRecordingDuration) / 60.0
        return Double(totalTranscribedWords) / minutes
    }
    
    var recordingDuration: TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Init
    
    init() {
        loadTodayStats()
    }
    
    // MARK: - Public Methods
    
    /// 加载今日统计
    func loadTodayStats() {
        todayStats = StatsStorage.shared.getTodayStats()
    }
    
    /// 录音开始时调用
    func onRecordingStarted() {
        recordingStartTime = Date()
        recordedPackets = 0
        
        // 增加录音次数
        StatsStorage.shared.incrementRecordingCount()
        loadTodayStats()
    }
    
    /// 录音结束时调用
    func onRecordingEnded() {
        // 计算本次录音时长
        if let startTime = recordingStartTime {
            let duration = Int(Date().timeIntervalSince(startTime))
            StatsStorage.shared.addRecordingDuration(duration)
        }
        
        recordingStartTime = nil
        loadTodayStats()
    }
    
    /// 收到转写结果时调用
    func onTranscriptionReceived(_ text: String) {
        let wordCount = WordCounter.countWords(text)
        if wordCount > 0 {
            StatsStorage.shared.addTranscribedWords(wordCount)
            loadTodayStats()
        }
    }
    
    func resetRecordingStats() {
        recordedPackets = 0
        recordingStartTime = nil
    }
}
