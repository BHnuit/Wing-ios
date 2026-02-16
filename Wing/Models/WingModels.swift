//
//  WingModels.swift
//  Wing
//
//  Created on 2026-01-28.
//

import Foundation
import SwiftData

// MARK: - Enums

/**
 * 会话状态枚举
 */
enum SessionStatus: String, Codable {
    /// 正在记录中
    case recording = "RECORDING"
    /// 正在处理中（AI 合成中）
    case processing = "PROCESSING"
    /// 已完成（已生成日记）
    case completed = "COMPLETED"
}

/**
 * 碎片类型枚举
 */
enum FragmentType: String, Codable {
    /// 文本类型
    case text = "TEXT"
    /// 图片类型
    case image = "IMAGE"
}

/**
 * 语言类型
 */
enum Language: String, Codable, CaseIterable {
    case zh = "zh"
    case en = "en"
    case ja = "ja"
    
    var displayName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }
}

/**
 * AI 供应商类型
 */
enum AiProvider: String, Codable {
    case gemini = "gemini"
    case openai = "openai"
    case deepseek = "deepseek"
    case custom = "custom"
}

/**
 * 文风类型
 */
enum WritingStyle: String, Codable {
    case letter = "letter"
    case prose = "prose"
    case report = "report"
    case custom = "custom"
    
    nonisolated var defaultPrompt: String {
        switch self {
        case .letter:
            return NSLocalizedString("prompt.tone.letter", value: "Tone: Write as a warm personal letter to the reader, using intimate and conversational style.", comment: "Letter writing style prompt")
        case .prose:
            return NSLocalizedString("prompt.tone.prose", value: "Tone: Warm, reflective, literary prose.", comment: "Prose writing style prompt")
        case .report:
            return NSLocalizedString("prompt.tone.report", value: "Tone: Structured and objective, like a daily report with clear sections.", comment: "Report writing style prompt")
        case .custom:
            return ""
        }
    }
}

extension AppSettings {
    static var defaultInsightPrompt: String {
        String(localized: "prompt.insight.default", defaultValue: "Psychological insights and encouragement (2-3 sentences)")
    }
}

/**
 * 记忆类型
 */
enum MemoryType: String, Codable {
    case semantic = "semantic"
    case episodic = "episodic"
    case procedural = "procedural"
}

/**
 * 待办优先级
 */
enum TodoPriority: String, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
}

/**
 * 主题类型
 */
enum Theme: String, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
}

/**
 * 页面字体
 */
enum PageFont: String, Codable {
    case system = "system"
    case sourceHanSans = "source-han-sans"
    case sourceHanSerif = "source-han-serif"
    case xlwk = "xlwk"
}



/**
 * 字号大小
 */
enum FontSize: String, Codable {
    case large = "large"
    case medium = "medium"
    case small = "small"
}

/**
 * 模型返回语言
 */
enum ModelLanguage: String, Codable {
    case zh = "zh"
    case en = "en"
    case same = "same"
}



// MARK: - RawFragment

/**
 * 原始碎片记录接口
 * 表示用户输入的单个记录片段（文本或图片）
 */
@Model
final class RawFragment {
    /// 唯一标识符
    @Attribute(.unique) var id: UUID
    
    /// 文本内容（图片类型时可能为空或包含描述）
    var content: String
    
    /// 图片数据，仅当 type 为 IMAGE 时存在
    /// 使用 @Attribute(.externalStorage) 避免数据库文件膨胀
    @Attribute(.externalStorage) var imageData: Data?
    
    /// 时间戳（Unix 毫秒）
    var timestamp: Int64
    
    /// 碎片类型
    var type: FragmentType
    
    /// 编辑时间戳（Unix 毫秒），若存在则表示消息已被编辑
    var editedAt: Int64?
    
    /// 是否正在处理中（例如图片上传/压缩）
    /// 默认为 false。若为 true，UI 应显示加载态
    var isProcessing: Bool
    
    /// 关联的每日会话（反向关系）
    var dailySession: DailySession?
    
    init(
        id: UUID = UUID(),
        content: String,
        imageData: Data? = nil,
        timestamp: Int64,
        type: FragmentType,
        editedAt: Int64? = nil,
        isProcessing: Bool = false
    ) {
        self.id = id
        self.content = content
        self.imageData = imageData
        self.timestamp = timestamp
        self.type = type
        self.editedAt = editedAt
        self.isProcessing = isProcessing
    }
}

// MARK: - WingTodo

/**
 * 待办事项
 * 作为结构体，遵循 Codable 协议，嵌入在 WingEntry 中
 */
struct WingTodo: Codable, Hashable {
    /// 待办标题
    var title: String
    
    /// 优先级
    var priority: TodoPriority
    
    /// 是否已完成；未设置视为 false
    var completed: Bool
    
    init(
        title: String,
        priority: TodoPriority = .medium,
        completed: Bool = false
    ) {
        self.title = title
        self.priority = priority
        self.completed = completed
    }
}

// MARK: - EditHistoryItem

/**
 * 编辑历史单条记录
 * 保存编辑前的 title 与 markdownContent 快照，用于恢复旧版本
 */
struct EditHistoryItem: Codable, Hashable {
    /// 创建时间戳（Unix 毫秒）
    var createdAt: Int64
    
    /// 编辑前的标题
    var title: String
    
    /// 编辑前的 Markdown 内容
    var markdownContent: String
    
    init(
        createdAt: Int64,
        title: String,
        markdownContent: String
    ) {
        self.createdAt = createdAt
        self.title = title
        self.markdownContent = markdownContent
    }
}

// MARK: - WingEntry

/**
 * 日记条目接口
 * 表示由 AI 合成的完整日记，包含标题、摘要、正文、洞察、待办等
 */
@Model
final class WingEntry {
    /// 唯一标识符
    @Attribute(.unique) var id: UUID
    
    /// 日记标题
    var title: String
    
    /// 一句话摘要
    var summary: String
    
    /// 心情 emoji（单个 emoji 字符）
    var mood: String
    
    /// Markdown 格式的日记正文
    var markdownContent: String
    
    /// AI 生成的洞察（心理学视角的深度分析与鼓励）
    var aiInsights: String
    
    /// 待办事项列表（存储为 JSON 字符串，通过计算属性访问）
    @Attribute(.externalStorage) private var todosData: Data?
    
    /// 创建时间戳（Unix 毫秒）
    var createdAt: Int64
    
    /// 最后手动编辑时间戳（Unix 毫秒）
    var editedAt: Int64?
    
    /// 编辑历史（存储为 JSON 字符串，通过计算属性访问）
    @Attribute(.externalStorage) private var editHistoryData: Data?
    
    /// 收拢生成完成时间戳（Unix 毫秒）
    var generatedAt: Int64?
    
    /// 图片映射：fragmentId -> imageData
    /// 使用 @Attribute(.externalStorage) 避免数据库文件膨胀
    @Attribute(.externalStorage) private var imagesData: Data?
    
    /// 关联的每日会话（反向关系）
    var dailySession: DailySession?
    
    /// 待办事项列表（计算属性）
    var todos: [WingTodo] {
        get {
            guard let data = todosData else { return [] }
            do {
                return try JSONDecoder().decode([WingTodo].self, from: data)
            } catch {
                return []
            }
        }
        set {
            do {
                todosData = try JSONEncoder().encode(newValue)
            } catch {
                todosData = nil
            }
        }
    }
    
    /// 编辑历史（计算属性）
    var editHistory: [EditHistoryItem] {
        get {
            guard let data = editHistoryData else { return [] }
            do {
                return try JSONDecoder().decode([EditHistoryItem].self, from: data)
            } catch {
                return []
            }
        }
        set {
            do {
                editHistoryData = try JSONEncoder().encode(newValue)
            } catch {
                editHistoryData = nil
            }
        }
    }
    
    /// 图片映射（计算属性）
    var images: [UUID: Data] {
        get {
            guard let data = imagesData else { return [:] }
            do {
                // 将 UUID 转换为 String 进行 JSON 编码
                let dict = try JSONDecoder().decode([String: Data].self, from: data)
                return dict.compactMapKeys { UUID(uuidString: $0) }
            } catch {
                return [:]
            }
        }
        set {
            do {
                // 将 UUID 转换为 String 进行 JSON 编码
                let stringDict = newValue.reduce(into: [String: Data]()) { result, pair in
                    result[pair.key.uuidString] = pair.value
                }
                imagesData = try JSONEncoder().encode(stringDict)
            } catch {
                imagesData = nil
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        mood: String,
        markdownContent: String,
        aiInsights: String = "",
        todos: [WingTodo] = [],
        createdAt: Int64,
        editedAt: Int64? = nil,
        editHistory: [EditHistoryItem] = [],
        generatedAt: Int64? = nil,
        images: [UUID: Data] = [:]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.mood = mood
        self.markdownContent = markdownContent
        self.aiInsights = aiInsights
        self.createdAt = createdAt
        self.editedAt = editedAt
        self.generatedAt = generatedAt
        
        // 使用计算属性的 setter 来初始化
        self.todos = todos
        self.editHistory = editHistory
        self.images = images
    }
}

// MARK: - DailySession

/**
 * 每日会话接口
 * 表示一天内的所有碎片记录和对应的日记生成状态
 */
@Model
final class DailySession {
    /// 唯一标识符
    @Attribute(.unique) var id: UUID
    
    /// 日期（YYYY-MM-DD 格式）
    var date: String
    
    /// 会话状态
    var status: SessionStatus
    
    /// 碎片记录列表（关系）
    @Relationship(deleteRule: .cascade, inverse: \RawFragment.dailySession)
    var fragments: [RawFragment] = []
    
    /// 最终生成的日记条目 ID
    var finalEntryId: UUID?
    
    /// 最终生成的日记条目（关系）
    @Relationship(inverse: \WingEntry.dailySession)
    var finalEntry: WingEntry?
    
    /// 当天每次触发收拢的时间戳数组（存储为 JSON）
    @Attribute(.externalStorage) private var gatherStartedAtData: Data?
    
    /// 每次收拢完成记录（存储为 JSON）
    @Attribute(.externalStorage) private var gatherCompletionsData: Data?
    
    /// 当天每次触发收拢的时间戳数组（计算属性）
    var gatherStartedAt: [Int64] {
        get {
            guard let data = gatherStartedAtData else { return [] }
            do {
                return try JSONDecoder().decode([Int64].self, from: data)
            } catch {
                return []
            }
        }
        set {
            do {
                gatherStartedAtData = try JSONEncoder().encode(newValue)
            } catch {
                gatherStartedAtData = nil
            }
        }
    }
    
    /// 每次收拢完成记录（计算属性）
    var gatherCompletions: [GatherCompletion] {
        get {
            guard let data = gatherCompletionsData else { return [] }
            do {
                return try JSONDecoder().decode([GatherCompletion].self, from: data)
            } catch {
                return []
            }
        }
        set {
            do {
                gatherCompletionsData = try JSONEncoder().encode(newValue)
            } catch {
                gatherCompletionsData = nil
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        date: String,
        status: SessionStatus = .recording,
        fragments: [RawFragment] = [],
        finalEntryId: UUID? = nil,
        gatherStartedAt: [Int64] = [],
        gatherCompletions: [GatherCompletion] = []
    ) {
        self.id = id
        self.date = date
        self.status = status
        self.fragments = fragments
        self.finalEntryId = finalEntryId
        
        // 使用计算属性的 setter 来初始化
        self.gatherStartedAt = gatherStartedAt
        self.gatherCompletions = gatherCompletions
    }
}

/**
 * 收拢完成记录
 * 遵循 Sendable 协议以支持跨 actor 边界传递
 */
struct GatherCompletion: Codable, Hashable, Sendable {
    /// 完成时间戳
    let completedAt: Int64
    
    /// 日记条目 ID
    let entryId: UUID
    
    /// 日记标题
    let title: String
    
    init(
        completedAt: Int64,
        entryId: UUID,
        title: String
    ) {
        self.completedAt = completedAt
        self.entryId = entryId
        self.title = title
    }
}

// MARK: - Memory Models

/**
 * 语义记忆接口
 * 存储用户的基本事实信息，如姓名、位置、喜好等
 */
@Model
final class SemanticMemory {
    /// 唯一标识符
    @Attribute(.unique) var id: UUID
    
    /// 记忆类型
    var type: MemoryType
    
    /// 记忆键，如 "name", "location", "favorite_music"
    var key: String
    
    /// 记忆值，如 "小夏", "成都", "五月天"
    var value: String
    
    /// 置信度 0-1，多次提及则提高
    var confidence: Double
    
    /// 来源日记ID列表（存储为 JSON）
    @Attribute(.externalStorage) private var sourceEntryIdsData: Data?
    
    /// 创建时间戳（Unix 毫秒）
    var createdAt: Int64
    
    /// 更新时间戳（Unix 毫秒）
    var updatedAt: Int64
    
    /// 来源日记ID列表（计算属性）
    var sourceEntryIds: [UUID] {
        get {
            guard let data = sourceEntryIdsData else { return [] }
            do {
                let stringArray = try JSONDecoder().decode([String].self, from: data)
                return stringArray.compactMap { UUID(uuidString: $0) }
            } catch {
                return []
            }
        }
        set {
            do {
                let stringArray = newValue.map { $0.uuidString }
                sourceEntryIdsData = try JSONEncoder().encode(stringArray)
            } catch {
                sourceEntryIdsData = nil
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        type: MemoryType = .semantic,
        key: String,
        value: String,
        confidence: Double = 0.5,
        sourceEntryIds: [UUID] = [],
        createdAt: Int64,
        updatedAt: Int64
    ) {
        self.id = id
        self.type = type
        self.key = key
        self.value = value
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        // 使用计算属性的 setter 来初始化
        self.sourceEntryIds = sourceEntryIds
    }
}

/**
 * 情景记忆接口
 * 记录特定时间、地点的事件和情绪
 */
@Model
final class EpisodicMemory {
    /// 唯一标识符
    @Attribute(.unique) var id: UUID
    
    /// 记忆类型
    var type: MemoryType
    
    /// 事件描述，如 "生日那天，我陪你听了歌"
    var event: String
    
    /// 情绪，如 "开心", "焦虑"
    var emotion: String?
    
    /// 日期 YYYY-MM-DD
    var date: String
    
    /// 上下文信息
    var context: String?
    
    /// 来源日记ID
    var sourceEntryId: UUID
    
    /// 创建时间戳（Unix 毫秒）
    var createdAt: Int64
    
    init(
        id: UUID = UUID(),
        type: MemoryType = .episodic,
        event: String,
        emotion: String? = nil,
        date: String,
        context: String? = nil,
        sourceEntryId: UUID,
        createdAt: Int64
    ) {
        self.id = id
        self.type = type
        self.event = event
        self.emotion = emotion
        self.date = date
        self.context = context
        self.sourceEntryId = sourceEntryId
        self.createdAt = createdAt
    }
}

/**
 * 程序性记忆接口
 * 学习用户的交互偏好和行为模式
 */
@Model
final class ProceduralMemory {
    /// 唯一标识符
    @Attribute(.unique) var id: UUID
    
    /// 记忆类型
    var type: MemoryType
    
    /// 行为模式，如 "不喜欢被打断"
    var pattern: String
    
    /// 偏好描述，如 "喜欢在夜晚倾诉"
    var preference: String
    
    /// 触发条件，如 "心情不好时用'唉……'开头"
    var trigger: String?
    
    /// 出现频率
    var frequency: Int
    
    /// 来源日记ID列表（存储为 JSON）
    @Attribute(.externalStorage) private var sourceEntryIdsData: Data?
    
    /// 创建时间戳（Unix 毫秒）
    var createdAt: Int64
    
    /// 更新时间戳（Unix 毫秒）
    var updatedAt: Int64
    
    /// 来源日记ID列表（计算属性）
    var sourceEntryIds: [UUID] {
        get {
            guard let data = sourceEntryIdsData else { return [] }
            do {
                let stringArray = try JSONDecoder().decode([String].self, from: data)
                return stringArray.compactMap { UUID(uuidString: $0) }
            } catch {
                return []
            }
        }
        set {
            do {
                let stringArray = newValue.map { $0.uuidString }
                sourceEntryIdsData = try JSONEncoder().encode(stringArray)
            } catch {
                sourceEntryIdsData = nil
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        type: MemoryType = .procedural,
        pattern: String,
        preference: String,
        trigger: String? = nil,
        frequency: Int = 1,
        sourceEntryIds: [UUID] = [],
        createdAt: Int64,
        updatedAt: Int64
    ) {
        self.id = id
        self.type = type
        self.pattern = pattern
        self.preference = preference
        self.trigger = trigger
        self.frequency = frequency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        // 使用计算属性的 setter 来初始化
        self.sourceEntryIds = sourceEntryIds
    }
}

// MARK: - AppSettings

/**
 * 应用设置接口
 * 存储用户的所有配置选项，包括 AI 配置、界面设置、功能开关等
 * 
 * 建议：使用 @Model 作为单例，或者使用 @AppStorage 管理简单字段
 * 这里使用 @Model 以便与 SwiftData 集成，但也可以考虑使用 UserDefaults/@AppStorage
 */
@Model
final class AppSettings {
    /// 唯一标识符（用于单例模式）
    @Attribute(.unique) var id: UUID
    
    /// 按 AI 供应商分别存储的模型名称
    /// 存储为 JSON 字符串
    @Attribute(.externalStorage) private var aiModelsData: Data?
    
    /// AI 供应商选择
    var aiProvider: AiProvider
    
    /// 自定义 API Base URL（仅当 aiProvider 为 custom 时使用）
    var aiBaseUrl: String?
    
    /// 界面语言
    var language: Language
    
    /// 页面主题：system 跟随系统、light 亮色、dark 暗色
    var theme: Theme
    
    /// 页面字体
    var pageFont: PageFont
    
    /// 全站字号：large 大、medium 中、small 小
    var fontSize: FontSize
    
    /// 模型返回内容的语言：zh / en / same（与页面一致）
    var modelLanguage: ModelLanguage
    
    /// 手动编辑日记时是否写入编辑历史
    var keepEditHistory: Bool
    
    /// 导出时是否备份所有设置（模型配置等密钥信息）
    var backupApiKeys: Bool
    
    /// 文风：letter 书信体、prose 散文体、report 报告体、custom 自定义
    var writingStyle: WritingStyle
    
    /// 自定义文风时的提示词
    var writingStylePrompt: String?
    
    /// 猫头鹰洞察的自定义提示语
    var insightPrompt: String?
    
    /// 是否启用长期记忆功能（Beta）
    var enableLongTermMemory: Bool
    
    /// 是否自动提取记忆（日记生成后自动提取）
    var memoryExtractionAuto: Bool
    
    /// 是否在生成日记时检索记忆（向AI传递记忆内容，需记忆数≥100）
    var memoryRetrievalEnabled: Bool
    
    /// 日记生成语言设置
    var journalLanguage: JournalLanguage = JournalLanguage.auto
    
    /// 双语界面模式（暂未完全启用）
    var bilingualMode: Bool = false
    
    /// 按 AI 供应商分别存储的模型名称（计算属性）
    var aiModels: [AiProvider: String] {
        get {
            guard let data = aiModelsData else { return [:] }
            do {
                let dict = try JSONDecoder().decode([String: String].self, from: data)
                return dict.compactMapKeys { AiProvider(rawValue: $0) }
            } catch {
                return [:]
            }
        }
        set {
            do {
                let stringDict = newValue.reduce(into: [String: String]()) { result, pair in
                    result[pair.key.rawValue] = pair.value
                }
                aiModelsData = try JSONEncoder().encode(stringDict)
            } catch {
                aiModelsData = nil
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        aiProvider: AiProvider = .gemini,
        aiBaseUrl: String? = nil,
        aiModels: [AiProvider: String] = [:],
        language: Language = .zh,
        theme: Theme = .system,
        pageFont: PageFont = .system,
        fontSize: FontSize = .medium,
        modelLanguage: ModelLanguage = .same,
        keepEditHistory: Bool = false,
        backupApiKeys: Bool = true,
        writingStyle: WritingStyle = .prose,
        writingStylePrompt: String? = nil,
        insightPrompt: String? = nil,
        enableLongTermMemory: Bool = false,
        memoryExtractionAuto: Bool = false,
        memoryRetrievalEnabled: Bool = false,
        journalLanguage: JournalLanguage = .auto,
        bilingualMode: Bool = false
    ) {
        self.id = id
        self.aiProvider = aiProvider
        self.aiBaseUrl = aiBaseUrl
        self.language = language
        self.theme = theme
        self.pageFont = pageFont
        self.fontSize = fontSize
        self.modelLanguage = modelLanguage
        self.keepEditHistory = keepEditHistory
        self.backupApiKeys = backupApiKeys
        self.writingStyle = writingStyle
        self.writingStylePrompt = writingStylePrompt
        self.insightPrompt = insightPrompt
        self.enableLongTermMemory = enableLongTermMemory
        self.memoryExtractionAuto = memoryExtractionAuto
        self.memoryRetrievalEnabled = memoryRetrievalEnabled
        self.journalLanguage = journalLanguage
        
        // 使用计算属性的 setter 来初始化
        self.aiModels = aiModels
    }
}

// MARK: - Helper Extensions

extension Dictionary {
    /// 将字典的键从一种类型转换为另一种类型
    func compactMapKeys<T: Hashable>(_ transform: (Key) throws -> T?) rethrows -> [T: Value] {
        try self.reduce(into: [T: Value]()) { result, element in
            if let key = try transform(element.key) {
                result[key] = element.value
            }
        }
    }
}

