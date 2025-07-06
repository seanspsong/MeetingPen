import Foundation
import PencilKit
import AVFoundation
import CoreGraphics

// CGRect is already Codable in iOS 14+ / macOS 11+

// MARK: - Main Meeting Model
struct Meeting: Identifiable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var duration: TimeInterval
    var participants: [String]
    var tags: [String]
    var location: String?
    var isRecording: Bool
    var status: MeetingStatus
    
    // Core data components
    var audioData: AudioData
    var transcriptData: TranscriptData
    var handwritingData: MeetingHandwritingData
    var aiAnalysis: AIAnalysis
    
    // Metadata
    var createdAt: Date
    var lastModified: Date
    var version: Int
    
    init(title: String, participants: [String] = [], location: String? = nil, tags: [String] = []) {
        self.id = UUID()
        self.title = title
        self.date = Date()
        self.duration = 0
        self.participants = participants
        self.tags = tags
        self.location = location
        self.isRecording = false
        self.status = .created
        
        self.audioData = AudioData()
        self.transcriptData = TranscriptData()
        self.handwritingData = MeetingHandwritingData()
        self.aiAnalysis = AIAnalysis()
        
        self.createdAt = Date()
        self.lastModified = Date()
        self.version = 1
    }
    
    // MARK: - Computed Properties
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return "\(hours)hr \(minutes)min"
        } else if minutes > 0 {
            return "\(minutes)min"
        } else {
            return "\(seconds)sec"
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var summary: String {
        if !aiAnalysis.summary.isEmpty {
            return String(aiAnalysis.summary.prefix(100)) + (aiAnalysis.summary.count > 100 ? "..." : "")
        } else if !transcriptData.fullText.isEmpty {
            return String(transcriptData.fullText.prefix(100)) + (transcriptData.fullText.count > 100 ? "..." : "")
        } else {
            return "No summary available"
        }
    }
    
    var hasAudio: Bool {
        !audioData.segments.isEmpty
    }
    
    var hasTranscript: Bool {
        !transcriptData.segments.isEmpty
    }
    
    var hasHandwriting: Bool {
        !handwritingData.textSegments.isEmpty || !handwritingData.drawings.isEmpty
    }
    
    var hasAIAnalysis: Bool {
        !aiAnalysis.summary.isEmpty
    }
    
    // MARK: - Helper Methods
    mutating func updateLastModified() {
        lastModified = Date()
        version += 1
    }
}

// MARK: - Meeting Status
enum MeetingStatus: String, Codable, CaseIterable {
    case created = "created"
    case recording = "recording"
    case processing = "processing"
    case completed = "completed"
    case archived = "archived"
    
    var displayName: String {
        switch self {
        case .created: return "Created"
        case .recording: return "Recording"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }
}

// MARK: - Audio Data Model
struct AudioData: Codable {
    var segments: [AudioSegment]
    var totalDuration: TimeInterval
    var sampleRate: Double
    var channels: Int
    var format: AudioFormat
    var averageDecibels: Double
    var peakDecibels: Double
    
    init() {
        self.segments = []
        self.totalDuration = 0
        self.sampleRate = 44100
        self.channels = 1
        self.format = .m4a
        self.averageDecibels = 0
        self.peakDecibels = 0
    }
    
    var formattedSize: String {
        let totalSize = segments.reduce(0) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
}

struct AudioSegment: Identifiable, Codable {
    let id: UUID
    var fileURL: URL?
    var fileName: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var duration: TimeInterval
    var fileSize: Int64
    var checksum: String
    var isProcessed: Bool
    var qualityScore: Double
    
    init(fileName: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.id = UUID()
        self.fileName = fileName
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime - startTime
        self.fileSize = 0
        self.checksum = ""
        self.isProcessed = false
        self.qualityScore = 0.0
    }
}

enum AudioFormat: String, Codable, CaseIterable {
    case m4a = "m4a"
    case mp3 = "mp3"
    case wav = "wav"
    case aac = "aac"
}

// MARK: - Transcript Data Model
struct TranscriptData: Codable {
    var segments: [TranscriptSegment]
    var fullText: String
    var language: String
    var confidence: Double
    var processingTime: TimeInterval
    var speakerCount: Int
    var wordCount: Int
    
    init() {
        self.segments = []
        self.fullText = ""
        self.language = "en-US"
        self.confidence = 0.0
        self.processingTime = 0
        self.speakerCount = 0
        self.wordCount = 0
    }
    
    func searchText(_ query: String) -> [TranscriptSegment] {
        return segments.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }
}

struct TranscriptSegment: Identifiable, Codable {
    let id: UUID
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var speaker: Speaker?
    var confidence: Double
    var words: [TranscriptWord]
    var isEdited: Bool
    
    init(text: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Double = 0.0) {
        self.id = UUID()
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.words = []
        self.isEdited = false
    }
    
    var duration: TimeInterval {
        endTime - startTime
    }
    
    var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: TimeInterval(startTime)) ?? "00:00"
    }
}

struct TranscriptWord: Codable {
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var confidence: Double
    
    init(text: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Double = 0.0) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}

struct Speaker: Identifiable, Codable {
    let id: UUID
    var name: String
    var identifier: String
    var voiceProfile: VoiceProfile?
    var segments: [UUID] // References to TranscriptSegment IDs
    
    init(name: String, identifier: String = "") {
        self.id = UUID()
        self.name = name
        self.identifier = identifier.isEmpty ? "speaker_\(UUID().uuidString.prefix(8))" : identifier
        self.segments = []
    }
}

struct VoiceProfile: Codable {
    var pitch: Double
    var tone: Double
    var pace: Double
    var confidence: Double
    
    init(pitch: Double = 0, tone: Double = 0, pace: Double = 0, confidence: Double = 0) {
        self.pitch = pitch
        self.tone = tone
        self.pace = pace
        self.confidence = confidence
    }
}

// MARK: - Handwriting Data Model
struct MeetingHandwritingData: Codable {
    var textSegments: [HandwritingTextSegment]
    var drawings: [HandwritingDrawing]
    var pages: [HandwritingPage]
    var totalWordCount: Int
    var recognitionAccuracy: Double
    var processingTime: TimeInterval
    
    init() {
        self.textSegments = []
        self.drawings = []
        self.pages = []
        self.totalWordCount = 0
        self.recognitionAccuracy = 0.0
        self.processingTime = 0
    }
    
    var allRecognizedText: String {
        textSegments.map { $0.recognizedText }.joined(separator: "\n")
    }
    
    func searchHandwriting(_ query: String) -> [HandwritingTextSegment] {
        return textSegments.filter { $0.recognizedText.localizedCaseInsensitiveContains(query) }
    }
}

struct HandwritingTextSegment: Identifiable, Codable {
    let id: UUID
    var recognizedText: String
    var originalText: String // User-corrected version
    var confidence: Double
    var boundingBox: CGRect
    var timestamp: TimeInterval
    var pageIndex: Int
    var strokeData: Data? // PKDrawing data
    var isEdited: Bool
    
    init(recognizedText: String, confidence: Double = 0.0, boundingBox: CGRect = .zero, timestamp: TimeInterval = 0, pageIndex: Int = 0) {
        self.id = UUID()
        self.recognizedText = recognizedText
        self.originalText = recognizedText
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.timestamp = timestamp
        self.pageIndex = pageIndex
        self.isEdited = false
    }
    
    var displayText: String {
        isEdited ? originalText : recognizedText
    }
}

struct HandwritingDrawing: Identifiable, Codable {
    let id: UUID
    var imageData: Data? // PNG/JPEG data
    var drawingData: Data? // PKDrawing data
    var boundingBox: CGRect
    var timestamp: TimeInterval
    var pageIndex: Int
    var title: String
    var tags: [String]
    var isAnnotation: Bool
    
    init(boundingBox: CGRect = .zero, timestamp: TimeInterval = 0, pageIndex: Int = 0, title: String = "", isAnnotation: Bool = false) {
        self.id = UUID()
        self.boundingBox = boundingBox
        self.timestamp = timestamp
        self.pageIndex = pageIndex
        self.title = title
        self.tags = []
        self.isAnnotation = isAnnotation
    }
}

struct HandwritingPage: Identifiable, Codable {
    let id: UUID
    var pageNumber: Int
    var backgroundImage: Data?
    var fullDrawingData: Data? // Complete PKDrawing for the page
    var thumbnailData: Data?
    var createdAt: Date
    var lastModified: Date
    
    init(pageNumber: Int) {
        self.id = UUID()
        self.pageNumber = pageNumber
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

// MARK: - AI Analysis Model
struct AIAnalysis: Codable {
    var summary: String
    var actionItems: [ActionItem]
    var keyDecisions: [String]
    var topics: [String]
    var sentiment: SentimentAnalysis
    var keyPhrases: [String]
    var entities: [Entity]
    var insights: [Insight]
    var processingTime: TimeInterval
    var confidence: Double
    
    init() {
        self.summary = ""
        self.actionItems = []
        self.keyDecisions = []
        self.topics = []
        self.sentiment = SentimentAnalysis()
        self.keyPhrases = []
        self.entities = []
        self.insights = []
        self.processingTime = 0
        self.confidence = 0.0
    }
}

struct ActionItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var assignee: String
    var dueDate: Date?
    var priority: Priority
    var status: ActionItemStatus
    var tags: [String]
    var createdAt: Date
    var completedAt: Date?
    
    init(title: String, description: String = "", assignee: String = "", dueDate: Date? = nil, priority: Priority = .medium) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.assignee = assignee
        self.dueDate = dueDate
        self.priority = priority
        self.status = .pending
        self.tags = []
        self.createdAt = Date()
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date() && status != .completed
    }
}

enum Priority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        rawValue.capitalized
    }
}

enum ActionItemStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

struct SentimentAnalysis: Codable {
    var overall: Double // -1 to 1
    var positive: Double
    var negative: Double
    var neutral: Double
    var confidence: Double
    
    init() {
        self.overall = 0.0
        self.positive = 0.0
        self.negative = 0.0
        self.neutral = 1.0
        self.confidence = 0.0
    }
    
    var overallSentiment: String {
        if overall > 0.1 {
            return "Positive"
        } else if overall < -0.1 {
            return "Negative"
        } else {
            return "Neutral"
        }
    }
}

struct Entity: Identifiable, Codable {
    let id: UUID
    var text: String
    var type: EntityType
    var confidence: Double
    var mentions: [EntityMention]
    
    init(text: String, type: EntityType, confidence: Double = 0.0) {
        self.id = UUID()
        self.text = text
        self.type = type
        self.confidence = confidence
        self.mentions = []
    }
}

enum EntityType: String, Codable, CaseIterable {
    case person = "person"
    case organization = "organization"
    case location = "location"
    case date = "date"
    case money = "money"
    case project = "project"
    case product = "product"
    case other = "other"
    
    var displayName: String {
        rawValue.capitalized
    }
}

struct EntityMention: Codable {
    var startOffset: Int
    var endOffset: Int
    var context: String
    var confidence: Double
    
    init(startOffset: Int, endOffset: Int, context: String, confidence: Double = 0.0) {
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.context = context
        self.confidence = confidence
    }
}

struct Insight: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var type: InsightType
    var confidence: Double
    var relevantData: [String: String]
    
    init(title: String, description: String, type: InsightType, confidence: Double = 0.0) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.type = type
        self.confidence = confidence
        self.relevantData = [:]
    }
}

enum InsightType: String, Codable, CaseIterable {
    case trend = "trend"
    case concern = "concern"
    case opportunity = "opportunity"
    case decision = "decision"
    case followUp = "follow_up"
    case risk = "risk"
    
    var displayName: String {
        switch self {
        case .trend: return "Trend"
        case .concern: return "Concern"
        case .opportunity: return "Opportunity"
        case .decision: return "Decision"
        case .followUp: return "Follow Up"
        case .risk: return "Risk"
        }
    }
}

// MARK: - Extensions and Sample Data
extension Meeting {
    static var sampleMeetings: [Meeting] {
        [
            Meeting(
                title: "Marketing Strategy Session",
                participants: ["Sarah", "Mike", "Alex"],
                location: "Conference Room A",
                tags: ["marketing", "strategy", "q4"]
            ).with {
                $0.duration = 2700 // 45 minutes
                $0.status = .completed
                $0.transcriptData.fullText = "Discussed Q4 campaign strategy, budget allocation, and team responsibilities. Sarah will lead the social media initiative while Mike focuses on influencer partnerships."
                $0.aiAnalysis.summary = "Marketing team aligned on Q4 campaign focusing on social media push with $50K budget. Key decisions made on timeline and team assignments."
                $0.aiAnalysis.actionItems = [
                    ActionItem(title: "Create social media content calendar", assignee: "Sarah", priority: .high),
                    ActionItem(title: "Research influencer partnerships", assignee: "Mike", priority: .medium),
                    ActionItem(title: "Prepare budget breakdown", assignee: "Alex", priority: .high)
                ]
                $0.aiAnalysis.keyDecisions = ["Q4 budget set at $50K", "Focus on social media marketing", "Timeline: Nov 1 - Dec 31"]
                $0.aiAnalysis.topics = ["marketing", "budget", "social media", "influencers"]
                $0.handwritingData.totalWordCount = 127
                $0.handwritingData.recognitionAccuracy = 0.94
            }
        ]
    }
}

// Helper extension for object modification
extension Meeting {
    func with(_ configure: (inout Meeting) -> Void) -> Meeting {
        var meeting = self
        configure(&meeting)
        return meeting
    }
} 