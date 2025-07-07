import Foundation
import SwiftUI
import Combine
import PencilKit

class MeetingStore: ObservableObject {
    @Published var meetings: [Meeting] = []
    @Published var currentMeeting: Meeting?
    @Published var isCreatingMeeting = false
    @Published var isRecording = false
    
    private let userDefaults = UserDefaults.standard
    private let meetingsKey = "SavedMeetings"
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    // Search optimization
    private var searchCache: [String: [Meeting]] = [:]
    private var meetingSearchableText: [UUID: String] = [:] // Cache searchable text
    
    init() {
        loadMeetings()
    }
    
    // MARK: - CRUD Operations
    
    func createMeeting(title: String, participants: [String] = [], location: String? = nil, tags: [String] = []) {
        let meeting = Meeting(title: title, participants: participants, location: location, tags: tags)
        meetings.insert(meeting, at: 0)
        currentMeeting = meeting
        clearSearchCache()
        saveMeetings()
    }
    
    func createMeeting(title: String, participants: [String] = [], location: String? = nil, tags: [String] = [], language: MeetingLanguage) {
        let meeting = Meeting(title: title, participants: participants, location: location, tags: tags, language: language)
        meetings.insert(meeting, at: 0)
        currentMeeting = meeting
        clearSearchCache()
        saveMeetings()
        print("💾 Created new meeting '\(title)' with language: \(language.displayName)")
    }
    
    func updateMeeting(_ meeting: Meeting) {
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            var updatedMeeting = meeting
            updatedMeeting.updateLastModified()
            meetings[index] = updatedMeeting
            if currentMeeting?.id == meeting.id {
                currentMeeting = updatedMeeting
            }
            // Clear search cache since meeting content changed
            clearSearchCache()
            saveMeetings()
        }
    }
    
    func deleteMeeting(_ meeting: Meeting) {
        // Clean up associated files
        cleanupMeetingFiles(meeting)
        
        meetings.removeAll { $0.id == meeting.id }
        if currentMeeting?.id == meeting.id {
            currentMeeting = nil
        }
        clearSearchCache()
        saveMeetings()
    }
    
    func deleteMeetings(at offsets: IndexSet) {
        let meetingsToDelete = offsets.map { meetings[$0] }
        meetingsToDelete.forEach { meeting in
            deleteMeeting(meeting)
        }
    }
    
    // MARK: - Recording Management
    
    func startRecording(for meeting: Meeting) {
        var updatedMeeting = meeting
        updatedMeeting.isRecording = true
        updatedMeeting.status = .recording
        updatedMeeting.date = Date()
        
        updateMeeting(updatedMeeting)
        isRecording = true
    }
    
    func stopRecording(for meeting: Meeting, duration: TimeInterval) {
        var updatedMeeting = meeting
        updatedMeeting.isRecording = false
        updatedMeeting.status = .processing
        updatedMeeting.duration = duration
        updatedMeeting.audioData.totalDuration = duration
        
        updateMeeting(updatedMeeting)
        isRecording = false
    }
    
    func completeProcessing(for meeting: Meeting) {
        var updatedMeeting = meeting
        updatedMeeting.status = .completed
        updateMeeting(updatedMeeting)
    }
    
    // MARK: - Audio Data Management
    
    func addAudioSegment(to meeting: Meeting, fileName: String, startTime: TimeInterval, endTime: TimeInterval, fileURL: URL? = nil) {
        var updatedMeeting = meeting
        var audioSegment = AudioSegment(fileName: fileName, startTime: startTime, endTime: endTime)
        audioSegment.fileURL = fileURL
        
        if let url = fileURL {
            audioSegment.fileSize = getFileSize(url)
            audioSegment.checksum = generateChecksum(url)
        }
        
        updatedMeeting.audioData.segments.append(audioSegment)
        updatedMeeting.audioData.totalDuration = updatedMeeting.audioData.segments.reduce(0) { $0 + $1.duration }
        
        updateMeeting(updatedMeeting)
    }
    
    func updateAudioMetadata(for meeting: Meeting, sampleRate: Double, channels: Int, format: AudioFormat) {
        var updatedMeeting = meeting
        updatedMeeting.audioData.sampleRate = sampleRate
        updatedMeeting.audioData.channels = channels
        updatedMeeting.audioData.format = format
        
        updateMeeting(updatedMeeting)
    }
    
    // MARK: - Transcript Data Management
    
    func addTranscriptSegment(to meeting: Meeting, text: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Double = 0.0, speaker: Speaker? = nil) {
        var updatedMeeting = meeting
        var segment = TranscriptSegment(text: text, startTime: startTime, endTime: endTime, confidence: confidence)
        segment.speaker = speaker
        
        updatedMeeting.transcriptData.segments.append(segment)
        updatedMeeting.transcriptData.fullText = updatedMeeting.transcriptData.segments.map { $0.text }.joined(separator: " ")
        updatedMeeting.transcriptData.wordCount = updatedMeeting.transcriptData.fullText.components(separatedBy: .whitespacesAndNewlines).count
        
        updateMeeting(updatedMeeting)
    }
    
    func updateTranscriptMetadata(for meeting: Meeting, language: String, confidence: Double, processingTime: TimeInterval) {
        var updatedMeeting = meeting
        updatedMeeting.transcriptData.language = language
        updatedMeeting.transcriptData.confidence = confidence
        updatedMeeting.transcriptData.processingTime = processingTime
        
        updateMeeting(updatedMeeting)
    }
    
    func editTranscriptSegment(in meeting: Meeting, segmentId: UUID, newText: String) {
        var updatedMeeting = meeting
        if let index = updatedMeeting.transcriptData.segments.firstIndex(where: { $0.id == segmentId }) {
            updatedMeeting.transcriptData.segments[index].text = newText
            updatedMeeting.transcriptData.segments[index].isEdited = true
            updatedMeeting.transcriptData.fullText = updatedMeeting.transcriptData.segments.map { $0.text }.joined(separator: " ")
            updateMeeting(updatedMeeting)
        }
    }
    
    // MARK: - Handwriting Data Management
    
    func addHandwritingTextSegment(to meeting: Meeting, recognizedText: String, confidence: Double, boundingBox: CGRect, timestamp: TimeInterval, pageIndex: Int, strokeData: Data? = nil) {
        var updatedMeeting = meeting
        var textSegment = HandwritingTextSegment(
            recognizedText: recognizedText,
            confidence: confidence,
            boundingBox: boundingBox,
            timestamp: timestamp,
            pageIndex: pageIndex
        )
        textSegment.strokeData = strokeData
        
        updatedMeeting.handwritingData.textSegments.append(textSegment)
        updatedMeeting.handwritingData.totalWordCount = updatedMeeting.handwritingData.textSegments.reduce(0) { 
            $0 + $1.recognizedText.components(separatedBy: .whitespacesAndNewlines).count 
        }
        
        updateMeeting(updatedMeeting)
    }
    
    func addHandwritingDrawing(to meeting: Meeting, drawingData: Data?, imageData: Data?, boundingBox: CGRect, timestamp: TimeInterval, pageIndex: Int, title: String = "", isAnnotation: Bool = false) {
        var updatedMeeting = meeting
        var drawing = HandwritingDrawing(
            boundingBox: boundingBox,
            timestamp: timestamp,
            pageIndex: pageIndex,
            title: title,
            isAnnotation: isAnnotation
        )
        drawing.drawingData = drawingData
        drawing.imageData = imageData
        
        updatedMeeting.handwritingData.drawings.append(drawing)
        updateMeeting(updatedMeeting)
    }
    
    func addHandwritingPage(to meeting: Meeting, pageNumber: Int, fullDrawingData: Data?, backgroundImage: Data? = nil, thumbnailData: Data? = nil) {
        var updatedMeeting = meeting
        var page = HandwritingPage(pageNumber: pageNumber)
        page.fullDrawingData = fullDrawingData
        page.backgroundImage = backgroundImage
        page.thumbnailData = thumbnailData
        
        updatedMeeting.handwritingData.pages.append(page)
        updateMeeting(updatedMeeting)
    }
    
    func updateHandwritingMetadata(for meeting: Meeting, recognitionAccuracy: Double, processingTime: TimeInterval) {
        var updatedMeeting = meeting
        updatedMeeting.handwritingData.recognitionAccuracy = recognitionAccuracy
        updatedMeeting.handwritingData.processingTime = processingTime
        
        updateMeeting(updatedMeeting)
    }
    
    func editHandwritingText(in meeting: Meeting, segmentId: UUID, correctedText: String) {
        var updatedMeeting = meeting
        if let index = updatedMeeting.handwritingData.textSegments.firstIndex(where: { $0.id == segmentId }) {
            updatedMeeting.handwritingData.textSegments[index].originalText = correctedText
            updatedMeeting.handwritingData.textSegments[index].isEdited = true
            updateMeeting(updatedMeeting)
        }
    }
    
    // MARK: - AI Analysis Management
    
    func updateAIAnalysis(for meeting: Meeting, summary: String, actionItems: [ActionItem] = [], keyDecisions: [String] = [], topics: [String] = [], sentiment: SentimentAnalysis? = nil, keyPhrases: [String] = [], entities: [Entity] = [], insights: [Insight] = [], processingTime: TimeInterval = 0, confidence: Double = 0.0) {
        var updatedMeeting = meeting
        updatedMeeting.aiAnalysis.summary = summary
        updatedMeeting.aiAnalysis.actionItems = actionItems
        updatedMeeting.aiAnalysis.keyDecisions = keyDecisions
        updatedMeeting.aiAnalysis.topics = topics
        updatedMeeting.aiAnalysis.keyPhrases = keyPhrases
        updatedMeeting.aiAnalysis.entities = entities
        updatedMeeting.aiAnalysis.insights = insights
        updatedMeeting.aiAnalysis.processingTime = processingTime
        updatedMeeting.aiAnalysis.confidence = confidence
        
        if let sentiment = sentiment {
            updatedMeeting.aiAnalysis.sentiment = sentiment
        }
        
        updateMeeting(updatedMeeting)
    }
    
    func updateActionItemStatus(in meeting: Meeting, actionItemId: UUID, status: ActionItemStatus) {
        var updatedMeeting = meeting
        if let index = updatedMeeting.aiAnalysis.actionItems.firstIndex(where: { $0.id == actionItemId }) {
            updatedMeeting.aiAnalysis.actionItems[index].status = status
            if status == .completed {
                updatedMeeting.aiAnalysis.actionItems[index].completedAt = Date()
            }
            updateMeeting(updatedMeeting)
        }
    }
    
    func addActionItem(to meeting: Meeting, title: String, description: String = "", assignee: String = "", dueDate: Date? = nil, priority: Priority = .medium) {
        var updatedMeeting = meeting
        let actionItem = ActionItem(title: title, description: description, assignee: assignee, dueDate: dueDate, priority: priority)
        updatedMeeting.aiAnalysis.actionItems.append(actionItem)
        updateMeeting(updatedMeeting)
    }
    
    // MARK: - OpenAI AI Generation
    
    /// Generate AI summary using OpenAI O3 model
    /// - Parameters:
    ///   - meeting: The meeting to generate summary for
    ///   - completion: Completion handler with success/failure result
    func generateAISummary(for meeting: Meeting, completion: @escaping (Result<Void, Error>) -> Void) {
        print("📝 [DEBUG] Starting AI summary generation for meeting: \(meeting.title)")
        
        // Use OpenAI service to generate summary
        OpenAIService.shared.generateMeetingSummary(for: meeting) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let summary):
                    print("✅ [DEBUG] Successfully generated AI summary (\(summary.count) characters)")
                    
                    // Update the meeting with AI summary
                    var updatedMeeting = meeting
                    updatedMeeting.aiAnalysis.summary = summary
                    
                    self?.updateMeeting(updatedMeeting)
                    completion(.success(()))
                    
                case .failure(let error):
                    print("❌ [DEBUG] Failed to generate AI summary: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Generate detailed meeting notes using OpenAI O3 model
    /// - Parameters:
    ///   - meeting: The meeting to generate notes for
    ///   - completion: Completion handler with success/failure result
    func generateMeetingNotes(for meeting: Meeting, completion: @escaping (Result<Void, Error>) -> Void) {
        print("📝 [DEBUG] Starting meeting notes generation for meeting: \(meeting.title)")
        
        // Use OpenAI service to generate notes
        OpenAIService.shared.generateMeetingNotes(for: meeting) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let generatedNotes):
                    print("✅ [DEBUG] Successfully generated meeting notes (\(generatedNotes.count) characters)")
                    
                    // Update the meeting with generated notes
                    var updatedMeeting = meeting
                    updatedMeeting.aiAnalysis.generatedNotes = generatedNotes
                    updatedMeeting.aiAnalysis.notesGeneratedAt = Date()
                    updatedMeeting.aiAnalysis.notesGenerationModel = "gpt-4o-mini"
                    
                    self?.updateMeeting(updatedMeeting)
                    completion(.success(()))
                    
                case .failure(let error):
                    print("❌ [DEBUG] Failed to generate meeting notes: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Clear generated notes from a meeting
    /// - Parameter meeting: The meeting to clear notes from
    func clearGeneratedNotes(for meeting: Meeting) {
        var updatedMeeting = meeting
        updatedMeeting.aiAnalysis.generatedNotes = ""
        updatedMeeting.aiAnalysis.notesGeneratedAt = nil
        updatedMeeting.aiAnalysis.notesGenerationModel = nil
        updateMeeting(updatedMeeting)
    }
    
    /// Generate action items using OpenAI
    /// - Parameters:
    ///   - meeting: The meeting to generate action items for
    ///   - completion: Completion handler with success/failure result
    func generateActionItems(for meeting: Meeting, completion: @escaping (Result<Void, Error>) -> Void) {
        print("📝 [DEBUG] Starting action items generation for meeting: \(meeting.title)")
        
        // Use OpenAI service to generate action items
        OpenAIService.shared.generateActionItems(for: meeting) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let actionItems):
                    print("✅ [DEBUG] Successfully generated \(actionItems.count) action items")
                    
                    // Update the meeting with generated action items
                    var updatedMeeting = meeting
                    updatedMeeting.aiAnalysis.actionItems = actionItems
                    
                    self?.updateMeeting(updatedMeeting)
                    completion(.success(()))
                    
                case .failure(let error):
                    print("❌ [DEBUG] Failed to generate action items: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Search and Filter
    
    func searchMeetings(query: String) -> [Meeting] {
        if query.isEmpty {
            return meetings
        }
        
        let lowercaseQuery = query.lowercased()
        
        // Check cache first
        if let cachedResults = searchCache[lowercaseQuery] {
            return cachedResults
        }
        
        // Build or update searchable text cache for meetings
        updateSearchableTextCache()
        
        let results = meetings.filter { meeting in
            guard let searchableText = meetingSearchableText[meeting.id] else { return false }
            return searchableText.contains(lowercaseQuery)
        }
        
        // Cache the results (limit cache size to prevent memory issues)
        if searchCache.count < 100 {
            searchCache[lowercaseQuery] = results
        }
        
        return results
    }
    
    /// Update the searchable text cache for all meetings
    private func updateSearchableTextCache() {
        for meeting in meetings {
            // Only update if not already cached or if meeting was modified
            if meetingSearchableText[meeting.id] == nil {
                let searchableText = [
                    meeting.title,
                    meeting.participants.joined(separator: " "),
                    meeting.tags.joined(separator: " "),
                    meeting.location ?? "",
                    meeting.aiAnalysis.summary,
                    meeting.transcriptData.fullText,
                    meeting.handwritingData.allRecognizedText
                ].joined(separator: " ").lowercased()
                
                meetingSearchableText[meeting.id] = searchableText
            }
        }
        
        // Remove cached text for meetings that no longer exist
        let meetingIds = Set(meetings.map { $0.id })
        meetingSearchableText = meetingSearchableText.filter { meetingIds.contains($0.key) }
    }
    
    /// Clear search cache when meetings are modified
    private func clearSearchCache() {
        searchCache.removeAll()
        meetingSearchableText.removeAll()
    }
    
    func meetingsForDate(_ date: Date) -> [Meeting] {
        let calendar = Calendar.current
        return meetings.filter { meeting in
            calendar.isDate(meeting.date, inSameDayAs: date)
        }
    }
    
    func meetingsWithStatus(_ status: MeetingStatus) -> [Meeting] {
        return meetings.filter { $0.status == status }
    }
    
    func meetingsWithTags(_ tags: [String]) -> [Meeting] {
        return meetings.filter { meeting in
            !Set(meeting.tags).intersection(Set(tags)).isEmpty
        }
    }
    
    // MARK: - Statistics
    
    var totalMeetings: Int {
        meetings.count
    }
    
    var totalRecordingTime: TimeInterval {
        meetings.reduce(0) { $0 + $1.duration }
    }
    
    var averageMeetingDuration: TimeInterval {
        guard !meetings.isEmpty else { return 0 }
        return totalRecordingTime / Double(meetings.count)
    }
    
    var meetingsThisWeek: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
        return meetings.filter { meeting in
            meeting.date >= startOfWeek
        }.count
    }
    
    var totalActionItems: Int {
        meetings.reduce(0) { $0 + $1.aiAnalysis.actionItems.count }
    }
    
    var completedActionItems: Int {
        meetings.reduce(0) { meetingCount, meeting in
            meetingCount + meeting.aiAnalysis.actionItems.filter { $0.status == .completed }.count
        }
    }
    
    var pendingActionItems: Int {
        meetings.reduce(0) { meetingCount, meeting in
            meetingCount + meeting.aiAnalysis.actionItems.filter { $0.status == .pending }.count
        }
    }
    
    var overdueActionItems: Int {
        meetings.reduce(0) { meetingCount, meeting in
            meetingCount + meeting.aiAnalysis.actionItems.filter { $0.isOverdue }.count
        }
    }
    
    var totalHandwritingWords: Int {
        meetings.reduce(0) { $0 + $1.handwritingData.totalWordCount }
    }
    
    var averageHandwritingAccuracy: Double {
        let meetingsWithHandwriting = meetings.filter { !$0.handwritingData.textSegments.isEmpty }
        guard !meetingsWithHandwriting.isEmpty else { return 0 }
        
        let totalAccuracy = meetingsWithHandwriting.reduce(0) { $0 + $1.handwritingData.recognitionAccuracy }
        return totalAccuracy / Double(meetingsWithHandwriting.count)
    }
    
    // MARK: - File Management
    
    private func cleanupMeetingFiles(_ meeting: Meeting) {
        // Remove audio files
        for segment in meeting.audioData.segments {
            if let fileURL = segment.fileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        
        // Remove handwriting image files if stored separately
        // This would depend on your implementation
    }
    
    private func getFileSize(_ url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func generateChecksum(_ url: URL) -> String {
        // Simple checksum generation - you might want to use a proper hash function
        return UUID().uuidString
    }
    
    // MARK: - Persistence
    
    private func loadMeetings() {
        print("💾 Loading meetings from UserDefaults...")
        
        // Try to load saved meetings from UserDefaults
        if let data = userDefaults.data(forKey: meetingsKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decodedMeetings = try decoder.decode([Meeting].self, from: data)
                meetings = decodedMeetings
                clearSearchCache() // Clear cache after loading
                print("💾 Successfully loaded \(meetings.count) meetings from storage")
                return
            } catch {
                print("❌ Failed to decode saved meetings: \(error)")
                print("💾 Will use sample data instead")
            }
        } else {
            print("💾 No saved meetings found, will use sample data")
        }
        
        // Fallback to sample data if no saved meetings or decoding failed
        meetings = Meeting.sampleMeetings
        clearSearchCache() // Clear cache after loading sample data
        print("💾 Loaded \(meetings.count) sample meetings")
        
        // Save the sample data so it persists
        saveMeetings()
    }
    
    private func saveMeetings() {
        print("💾 Saving \(meetings.count) meetings to UserDefaults...")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted // For debugging
            let encoded = try encoder.encode(meetings)
            userDefaults.set(encoded, forKey: meetingsKey)
            
            // Force synchronization to disk
            userDefaults.synchronize()
            
            print("💾 Successfully saved meetings to storage (\(encoded.count) bytes)")
        } catch {
            print("❌ Failed to save meetings: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Meeting Navigation
    
    func selectMeeting(_ meeting: Meeting) {
        currentMeeting = meeting
    }
    
    func clearCurrentMeeting() {
        currentMeeting = nil
    }
    
    // MARK: - Export and Import
    
    func exportMeeting(_ meeting: Meeting) -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(meeting)
        } catch {
            print("Failed to export meeting: \(error)")
            return nil
        }
    }
    
    func importMeeting(from data: Data) -> Bool {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let meeting = try decoder.decode(Meeting.self, from: data)
            meetings.insert(meeting, at: 0)
            clearSearchCache()
            saveMeetings()
            return true
        } catch {
            print("Failed to import meeting: \(error)")
            return false
        }
    }
    
    // MARK: - Backup and Restore
    
    func createBackup() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(meetings)
        } catch {
            print("Failed to create backup: \(error)")
            return nil
        }
    }
    
    func restoreFromBackup(_ data: Data) -> Bool {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let restoredMeetings = try decoder.decode([Meeting].self, from: data)
            meetings = restoredMeetings
            clearSearchCache()
            saveMeetings()
            return true
        } catch {
            print("Failed to restore from backup: \(error)")
            return false
        }
    }
}

// MARK: - Extensions

extension MeetingStore {
    func recentMeetings(limit: Int = 5) -> [Meeting] {
        Array(meetings.prefix(limit))
    }
    
    func upcomingActionItems(limit: Int = 10) -> [ActionItem] {
        let allActionItems = meetings.flatMap { $0.aiAnalysis.actionItems }
            .filter { $0.status == .pending }
            .sorted { item1, item2 in
                guard let date1 = item1.dueDate, let date2 = item2.dueDate else {
                    return item1.dueDate != nil
                }
                return date1 < date2
            }
        
        return Array(allActionItems.prefix(limit))
    }
    
    func meetingsWithAudio() -> [Meeting] {
        meetings.filter { $0.hasAudio }
    }
    
    func meetingsWithHandwriting() -> [Meeting] {
        meetings.filter { $0.hasHandwriting }
    }
    
    func meetingsWithAIAnalysis() -> [Meeting] {
        meetings.filter { $0.hasAIAnalysis }
    }
    
    func getMeetingsByParticipant(_ participant: String) -> [Meeting] {
        meetings.filter { $0.participants.contains(participant) }
    }
    
    func getMostActiveParticipants(limit: Int = 5) -> [(String, Int)] {
        let allParticipants = meetings.flatMap { $0.participants }
        let participantCounts = Dictionary(grouping: allParticipants) { $0 }
            .mapValues { $0.count }
        
        return Array(participantCounts.sorted { $0.value > $1.value }.prefix(limit))
    }
    
    func getPopularTags(limit: Int = 10) -> [(String, Int)] {
        let allTags = meetings.flatMap { $0.tags }
        let tagCounts = Dictionary(grouping: allTags) { $0 }
            .mapValues { $0.count }
        
        return Array(tagCounts.sorted { $0.value > $1.value }.prefix(limit))
    }
}

// MARK: - Utility Extensions

extension MeetingStore {
    func generateMeetingReport(_ meeting: Meeting) -> String {
        var report = """
        # Meeting Report: \(meeting.title)
        
        **Date:** \(meeting.formattedDate)
        **Duration:** \(meeting.formattedDuration)
        **Participants:** \(meeting.participants.joined(separator: ", "))
        **Location:** \(meeting.location ?? "N/A")
        **Tags:** \(meeting.tags.joined(separator: ", "))
        
        ## Summary
        \(meeting.aiAnalysis.summary)
        
        ## Key Decisions
        """
        
        for decision in meeting.aiAnalysis.keyDecisions {
            report += "\n- \(decision)"
        }
        
        report += "\n\n## Action Items"
        for actionItem in meeting.aiAnalysis.actionItems {
            report += "\n- **\(actionItem.title)** (Assigned to: \(actionItem.assignee), Priority: \(actionItem.priority.displayName), Status: \(actionItem.status.displayName))"
            if !actionItem.description.isEmpty {
                report += "\n  \(actionItem.description)"
            }
        }
        
        if !meeting.transcriptData.fullText.isEmpty {
            report += "\n\n## Transcript\n\(meeting.transcriptData.fullText)"
        }
        
        if !meeting.handwritingData.allRecognizedText.isEmpty {
            report += "\n\n## Handwritten Notes\n\(meeting.handwritingData.allRecognizedText)"
        }
        
        return report
    }
} 