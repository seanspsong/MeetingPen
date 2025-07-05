import Foundation
import SwiftUI
import Combine

class MeetingStore: ObservableObject {
    @Published var meetings: [Meeting] = []
    @Published var currentMeeting: Meeting?
    @Published var isCreatingMeeting = false
    @Published var isRecording = false
    
    private let userDefaults = UserDefaults.standard
    private let meetingsKey = "SavedMeetings"
    
    init() {
        loadMeetings()
    }
    
    // MARK: - CRUD Operations
    
    func createMeeting(title: String, participants: [String] = []) {
        let meeting = Meeting(title: title, participants: participants)
        meetings.insert(meeting, at: 0)
        currentMeeting = meeting
        saveMeetings()
    }
    
    func updateMeeting(_ meeting: Meeting) {
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = meeting
            if currentMeeting?.id == meeting.id {
                currentMeeting = meeting
            }
            saveMeetings()
        }
    }
    
    func deleteMeeting(_ meeting: Meeting) {
        meetings.removeAll { $0.id == meeting.id }
        if currentMeeting?.id == meeting.id {
            currentMeeting = nil
        }
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
        updatedMeeting.date = Date()
        
        updateMeeting(updatedMeeting)
        isRecording = true
    }
    
    func stopRecording(for meeting: Meeting, duration: TimeInterval) {
        var updatedMeeting = meeting
        updatedMeeting.isRecording = false
        updatedMeeting.duration = duration
        
        updateMeeting(updatedMeeting)
        isRecording = false
    }
    
    // MARK: - Search and Filter
    
    func searchMeetings(query: String) -> [Meeting] {
        if query.isEmpty {
            return meetings
        }
        
        return meetings.filter { meeting in
            meeting.title.localizedCaseInsensitiveContains(query) ||
            meeting.participants.joined(separator: " ").localizedCaseInsensitiveContains(query) ||
            meeting.transcript.localizedCaseInsensitiveContains(query) ||
            meeting.aiSummary.localizedCaseInsensitiveContains(query)
        }
    }
    
    func meetingsForDate(_ date: Date) -> [Meeting] {
        let calendar = Calendar.current
        return meetings.filter { meeting in
            calendar.isDate(meeting.date, inSameDayAs: date)
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
    
    // MARK: - Persistence
    
    private func loadMeetings() {
        // Load sample data for development
        if meetings.isEmpty {
            meetings = Meeting.sampleMeetings
        }
        
        // TODO: Implement actual persistence with Core Data or JSON
        // For now, we'll use sample data
        
        // If you want to load from UserDefaults:
        /*
        if let data = userDefaults.data(forKey: meetingsKey),
           let decodedMeetings = try? JSONDecoder().decode([Meeting].self, from: data) {
            meetings = decodedMeetings
        } else {
            meetings = Meeting.sampleMeetings
        }
        */
    }
    
    private func saveMeetings() {
        // TODO: Implement actual persistence
        // For now, we'll just keep in memory
        
        // If you want to save to UserDefaults:
        /*
        if let encoded = try? JSONEncoder().encode(meetings) {
            userDefaults.set(encoded, forKey: meetingsKey)
        }
        */
    }
    
    // MARK: - Meeting Navigation
    
    func selectMeeting(_ meeting: Meeting) {
        currentMeeting = meeting
    }
    
    func clearCurrentMeeting() {
        currentMeeting = nil
    }
    
    // MARK: - AI Integration Helpers
    
    func updateMeetingWithAISummary(_ meeting: Meeting, summary: String, actionItems: [ActionItem] = [], keyDecisions: [String] = []) {
        var updatedMeeting = meeting
        updatedMeeting.aiSummary = summary
        updatedMeeting.actionItems = actionItems
        updatedMeeting.keyDecisions = keyDecisions
        
        updateMeeting(updatedMeeting)
    }
    
    func updateMeetingTranscript(_ meeting: Meeting, transcript: String) {
        var updatedMeeting = meeting
        updatedMeeting.transcript = transcript
        
        updateMeeting(updatedMeeting)
    }
    
    func updateMeetingHandwrittenNotes(_ meeting: Meeting, notes: String) {
        var updatedMeeting = meeting
        updatedMeeting.handwrittenNotes = notes
        
        updateMeeting(updatedMeeting)
    }
}

// MARK: - Extensions

extension MeetingStore {
    func recentMeetings(limit: Int = 5) -> [Meeting] {
        Array(meetings.prefix(limit))
    }
    
    func upcomingActionItems() -> [ActionItem] {
        meetings.flatMap { $0.actionItems }
            .filter { !$0.isCompleted }
            .sorted { item1, item2 in
                guard let date1 = item1.dueDate, let date2 = item2.dueDate else {
                    return item1.dueDate != nil
                }
                return date1 < date2
            }
    }
} 