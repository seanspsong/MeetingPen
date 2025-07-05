import Foundation
import PencilKit

struct Meeting: Identifiable, Codable {
    let id = UUID()
    var title: String
    var date: Date
    var duration: TimeInterval
    var participants: [String]
    var audioFileURL: URL?
    var transcript: String
    var handwrittenNotes: String
    var aiSummary: String
    var actionItems: [ActionItem]
    var keyDecisions: [String]
    var isRecording: Bool
    var drawingData: Data?
    
    init(title: String, participants: [String] = []) {
        self.title = title
        self.date = Date()
        self.duration = 0
        self.participants = participants
        self.transcript = ""
        self.handwrittenNotes = ""
        self.aiSummary = ""
        self.actionItems = []
        self.keyDecisions = []
        self.isRecording = false
        self.drawingData = nil
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)hr \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var summary: String {
        if !aiSummary.isEmpty {
            return String(aiSummary.prefix(100)) + (aiSummary.count > 100 ? "..." : "")
        } else if !transcript.isEmpty {
            return String(transcript.prefix(100)) + (transcript.count > 100 ? "..." : "")
        } else {
            return "No summary available"
        }
    }
}

struct ActionItem: Identifiable, Codable {
    let id = UUID()
    var title: String
    var assignee: String
    var dueDate: Date?
    var isCompleted: Bool
    
    init(title: String, assignee: String = "", dueDate: Date? = nil) {
        self.title = title
        self.assignee = assignee
        self.dueDate = dueDate
        self.isCompleted = false
    }
}

// MARK: - Sample Data
extension Meeting {
    static var sampleMeetings: [Meeting] {
        [
            Meeting(
                title: "Marketing Strategy Session",
                participants: ["Sarah", "Mike", "Alex"]
            ).with {
                $0.duration = 2700 // 45 minutes
                $0.transcript = "Discussed Q4 campaign strategy, budget allocation, and team responsibilities."
                $0.aiSummary = "Marketing team aligned on Q4 campaign focusing on social media push with $50K budget. Key decisions made on timeline and team assignments."
                $0.actionItems = [
                    ActionItem(title: "Create social media content calendar", assignee: "Sarah"),
                    ActionItem(title: "Research influencer partnerships", assignee: "Mike"),
                    ActionItem(title: "Prepare budget breakdown", assignee: "Alex")
                ]
                $0.keyDecisions = ["Q4 budget set at $50K", "Focus on social media marketing", "Timeline: Nov 1 - Dec 31"]
            },
            Meeting(
                title: "Client Kickoff Meeting",
                participants: ["John", "Lisa", "Robert", "Emma", "David"]
            ).with {
                $0.duration = 4800 // 1hr 20min
                $0.date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                $0.transcript = "Project kickoff with client, discussed requirements, timeline, and deliverables."
                $0.aiSummary = "Successful project kickoff with clear timeline and deliverables established. Client requirements documented and team roles assigned."
                $0.actionItems = [
                    ActionItem(title: "Send project charter", assignee: "John"),
                    ActionItem(title: "Schedule technical review", assignee: "Lisa")
                ]
                $0.keyDecisions = ["Project timeline: 12 weeks", "Weekly check-ins on Fridays", "Technical lead: Lisa"]
            },
            Meeting(
                title: "Weekly Team Standup",
                participants: ["Team"]
            ).with {
                $0.duration = 900 // 15 minutes
                $0.date = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
                $0.transcript = "Quick team sync on current projects and blockers."
                $0.aiSummary = "Team is on track with current sprint. No major blockers identified."
                $0.actionItems = [
                    ActionItem(title: "Review PR #123", assignee: "Development Team")
                ]
                $0.keyDecisions = ["Sprint goals confirmed", "No scope changes needed"]
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