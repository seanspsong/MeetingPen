import SwiftUI

struct MeetingDetailView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var openAIService = OpenAIService.shared
    
    @State private var meeting: Meeting
    @State private var selectedTab = 0
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    
    init(meeting: Meeting) {
        self._meeting = State(initialValue: meeting)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            meetingHeader
            
            // Tab View
            TabView(selection: $selectedTab) {
                summaryTab
                    .tabItem {
                        Image(systemName: "doc.text")
                        Text("Summary")
                    }
                    .tag(0)
                
                transcriptTab
                    .tabItem {
                        Image(systemName: "waveform")
                        Text("Transcript")
                    }
                    .tag(1)
                
                notesTab
                    .tabItem {
                        Image(systemName: "pencil")
                        Text("Notes")
                    }
                    .tag(2)
                
                actionItemsTab
                    .tabItem {
                        Image(systemName: "checklist")
                        Text("Actions")
                    }
                    .tag(3)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEditSheet) {
            MeetingEditView(meeting: $meeting, onSave: { updatedMeeting in
                meetingStore.updateMeeting(updatedMeeting)
                meeting = updatedMeeting
            })
        }
        .alert("Delete Meeting", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                meetingStore.deleteMeeting(meeting)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this meeting? This action cannot be undone.")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(meeting: meeting)
        }
    }
    
    // MARK: - Meeting Header
    
    private var meetingHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { showingEditSheet = true }) {
                        Image(systemName: "pencil")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Menu {
                        Button("Delete Meeting") {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Text(meeting.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .lineLimit(2)
            
            HStack(spacing: 16) {
                Label(meeting.formattedDate, systemImage: "calendar")
                
                if meeting.duration > 0 {
                    Label(meeting.formattedDuration, systemImage: "clock")
                }
                
                if !meeting.participants.isEmpty {
                    Label("\(meeting.participants.count) participants", systemImage: "person.2")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Summary Tab
    
    private var summaryTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !meeting.aiAnalysis.summary.isEmpty {
                    aiSummaryCard
                } else {
                    generateSummaryCard
                }
                
                // OpenAI O3 Generated Meeting Notes Section
                if meeting.aiAnalysis.hasGeneratedNotes {
                    generatedNotesCard
                } else {
                    generateNotesCard
                }
                
                if !meeting.aiAnalysis.keyDecisions.isEmpty {
                    keyDecisionsCard
                }
                
                if !meeting.participants.isEmpty {
                    participantsCard
                }
            }
            .padding()
        }
    }
    
    // MARK: - Transcript Tab
    
    private var transcriptTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !meeting.transcriptData.fullText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Audio Transcript")
                            .font(.headline)
                        
                        Text(meeting.transcriptData.fullText)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Transcript Available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Audio transcription will appear here after recording")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Notes Tab
    
    private var notesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !meeting.handwritingData.allRecognizedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Handwritten Notes")
                            .font(.headline)
                        
                        Text(meeting.handwritingData.allRecognizedText)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Handwritten Notes")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Handwritten notes will appear here after recognition")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Action Items Tab
    
    private var actionItemsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !meeting.aiAnalysis.actionItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Action Items")
                            .font(.headline)
                        
                        ForEach(meeting.aiAnalysis.actionItems.indices, id: \.self) { index in
                            ActionItemRow(
                                actionItem: meeting.aiAnalysis.actionItems[index],
                                onToggle: { status in
                                    var updatedMeeting = meeting
                                    updatedMeeting.aiAnalysis.actionItems[index].status = status
                                    meetingStore.updateMeeting(updatedMeeting)
                                }
                            )
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checklist.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Action Items")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Action items will be extracted automatically from meeting content")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Supporting Views
    
    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("AI Summary")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
            }
            
            Text(meeting.aiAnalysis.summary)
                .font(.body)
                .textSelection(.enabled)
            
            HStack {
                Spacer()
                
                Button("Regenerate") {
                    generateAISummary()
                }
                .font(.caption)
                .disabled(openAIService.isGenerating)
                
                Button("Clear") {
                    var updatedMeeting = meeting
                    updatedMeeting.aiAnalysis.summary = ""
                    meetingStore.updateMeeting(updatedMeeting)
                    meeting = updatedMeeting
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var generateSummaryCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Generate AI Summary")
                .font(.headline)
            
            Text("Create an intelligent summary of this meeting with key points and action items")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if openAIService.isGenerating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating summary...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Generate Summary") {
                    generateAISummary()
                }
                .buttonStyle(.borderedProminent)
                .disabled(meeting.transcriptData.fullText.isEmpty && meeting.handwritingData.allRecognizedText.isEmpty)
            }
            
            if let error = openAIService.generationError {
                Text("Error: \(error.localizedDescription)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var generatedNotesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.orange)
                Text("AI Generated Meeting Notes")
                    .font(.headline)
                    .foregroundColor(.orange)
                Spacer()
                
                if let generatedAt = meeting.aiAnalysis.notesGeneratedAt {
                    Text(generatedAt, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(meeting.aiAnalysis.generatedNotes)
                .font(.body)
                .textSelection(.enabled)
            
            HStack {
                if let model = meeting.aiAnalysis.notesGenerationModel {
                    Text("Generated by \(model)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Regenerate") {
                    generateMeetingNotes()
                }
                .font(.caption)
                .disabled(openAIService.isGenerating)
                
                Button("Clear") {
                    meetingStore.clearGeneratedNotes(for: meeting)
                    if let updatedMeeting = meetingStore.meetings.first(where: { $0.id == meeting.id }) {
                        meeting = updatedMeeting
                    }
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var generateNotesCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Generate AI Meeting Notes")
                .font(.headline)
            
            Text("Create detailed, professional meeting notes using OpenAI O3 model. Combines audio transcription and handwritten notes into structured format.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if openAIService.isGenerating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating notes...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Generate Meeting Notes") {
                    generateMeetingNotes()
                }
                .buttonStyle(.borderedProminent)
                .disabled(meeting.transcriptData.fullText.isEmpty && meeting.handwritingData.allRecognizedText.isEmpty)
            }
            
            if let error = openAIService.generationError {
                Text("Error: \(error.localizedDescription)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var keyDecisionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal")
                    .foregroundColor(.green)
                Text("Key Decisions")
                    .font(.headline)
                    .foregroundColor(.green)
                Spacer()
            }
            
            ForEach(meeting.aiAnalysis.keyDecisions, id: \.self) { decision in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text(decision)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2")
                    .foregroundColor(.purple)
                Text("Participants")
                    .font(.headline)
                    .foregroundColor(.purple)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(meeting.participants, id: \.self) { participant in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.purple)
                        Text(participant)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - AI Generation
    
    private func generateAISummary() {
        print("🤖 [DEBUG] User triggered AI summary generation")
        
        meetingStore.generateAISummary(for: meeting) { result in
            switch result {
            case .success():
                print("✅ [DEBUG] AI summary generated successfully")
                // Update the local meeting object with the updated data
                if let updatedMeeting = meetingStore.meetings.first(where: { $0.id == meeting.id }) {
                    meeting = updatedMeeting
                }
            case .failure(let error):
                print("❌ [DEBUG] Failed to generate AI summary: \(error.localizedDescription)")
                // Error is already handled by the OpenAI service and displayed in the UI
            }
        }
    }
    
    private func generateMeetingNotes() {
        print("🤖 [DEBUG] User triggered meeting notes generation")
        
        meetingStore.generateMeetingNotes(for: meeting) { result in
            switch result {
            case .success():
                print("✅ [DEBUG] Meeting notes generated successfully")
                // Update the local meeting object with the updated data
                if let updatedMeeting = meetingStore.meetings.first(where: { $0.id == meeting.id }) {
                    meeting = updatedMeeting
                }
            case .failure(let error):
                print("❌ [DEBUG] Failed to generate meeting notes: \(error.localizedDescription)")
                // Error is already handled by the OpenAI service and displayed in the UI
            }
        }
    }
}

struct ActionItemRow: View {
    let actionItem: ActionItem
    let onToggle: (ActionItemStatus) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: { 
                let newStatus: ActionItemStatus = actionItem.status == .completed ? .pending : .completed
                onToggle(newStatus) 
            }) {
                Image(systemName: actionItem.status == .completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(actionItem.status == .completed ? .green : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(actionItem.title)
                    .font(.body)
                    .strikethrough(actionItem.status == .completed)
                    .foregroundColor(actionItem.status == .completed ? .secondary : .primary)
                
                if !actionItem.assignee.isEmpty {
                    Text("Assigned to: \(actionItem.assignee)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let dueDate = actionItem.dueDate {
                    Text("Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MeetingEditView: View {
    @Binding var meeting: Meeting
    let onSave: (Meeting) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var participants: [String]
    
    init(meeting: Binding<Meeting>, onSave: @escaping (Meeting) -> Void) {
        self._meeting = meeting
        self.onSave = onSave
        self._title = State(initialValue: meeting.wrappedValue.title)
        self._participants = State(initialValue: meeting.wrappedValue.participants)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Meeting Details")) {
                    TextField("Meeting Title", text: $title)
                }
                
                Section(header: Text("Participants")) {
                    ForEach(participants, id: \.self) { participant in
                        Text(participant)
                    }
                }
            }
            .navigationTitle("Edit Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var updatedMeeting = meeting
                        updatedMeeting.title = title
                        updatedMeeting.participants = participants
                        onSave(updatedMeeting)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ShareSheet: View {
    let meeting: Meeting
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Share Meeting")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                ShareOptionRow(icon: "doc.text", title: "Export as PDF", description: "Complete meeting summary with formatting")
                ShareOptionRow(icon: "text.alignleft", title: "Export as Text", description: "Plain text version for easy sharing")
                ShareOptionRow(icon: "envelope", title: "Email Summary", description: "Send meeting summary via email")
                ShareOptionRow(icon: "link", title: "Copy Link", description: "Share meeting via secure link")
            }
            .padding()
            
            Spacer()
        }
        .navigationTitle("Share")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct ShareOptionRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        Button(action: {
            // TODO: Implement sharing functionality
            print("Sharing: \(title)")
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    MeetingDetailView(meeting: Meeting.sampleMeetings[0])
        .environmentObject(MeetingStore())
} 