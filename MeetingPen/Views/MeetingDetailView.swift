import SwiftUI

struct MeetingDetailView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var meeting: Meeting
    @State private var selectedTab = 0
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    
    init(meeting: Meeting) {
        self._meeting = State(initialValue: meeting)
    }
    
    var body: some View {
        NavigationView {
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
        }
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
                if !meeting.aiSummary.isEmpty {
                    aiSummaryCard
                } else {
                    generateSummaryCard
                }
                
                if !meeting.keyDecisions.isEmpty {
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
                if !meeting.transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Audio Transcript")
                            .font(.headline)
                        
                        Text(meeting.transcript)
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
                if !meeting.handwrittenNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Handwritten Notes")
                            .font(.headline)
                        
                        Text(meeting.handwrittenNotes)
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
                if !meeting.actionItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Action Items")
                            .font(.headline)
                        
                        ForEach(meeting.actionItems.indices, id: \.self) { index in
                            ActionItemRow(
                                actionItem: meeting.actionItems[index],
                                onToggle: { isCompleted in
                                    meeting.actionItems[index].isCompleted = isCompleted
                                    meetingStore.updateMeeting(meeting)
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
            
            Text(meeting.aiSummary)
                .font(.body)
                .textSelection(.enabled)
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
            
            Button("Generate Summary") {
                // TODO: Implement AI summary generation
                print("Generating AI summary...")
            }
            .buttonStyle(.borderedProminent)
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
            
            ForEach(meeting.keyDecisions, id: \.self) { decision in
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
}

struct ActionItemRow: View {
    let actionItem: ActionItem
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: { onToggle(!actionItem.isCompleted) }) {
                Image(systemName: actionItem.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(actionItem.isCompleted ? .green : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(actionItem.title)
                    .font(.body)
                    .strikethrough(actionItem.isCompleted)
                    .foregroundColor(actionItem.isCompleted ? .secondary : .primary)
                
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
        NavigationView {
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