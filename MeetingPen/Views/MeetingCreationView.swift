import SwiftUI

struct MeetingCreationView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var participants: [String] = []
    @State private var newParticipant = ""

    
    // Optional binding for when used as a sheet
    var isPresented: Binding<Bool>?
    
    // Callback for when a meeting should be started with recording
    var onMeetingCreatedWithRecording: ((Meeting) -> Void)?
    
    init(isPresented: Binding<Bool>? = nil, onMeetingCreatedWithRecording: ((Meeting) -> Void)? = nil) {
        self.isPresented = isPresented
        self.onMeetingCreatedWithRecording = onMeetingCreatedWithRecording
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom navigation bar
            HStack {
                Button("Cancel") {
                    dismissView()
                }
                .foregroundColor(.blue)
                .padding(.leading)
                
                Spacer()
                
                Text("New Meeting")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Create") {
                    createMeetingOnly()
                }
                .foregroundColor(.blue)
                .fontWeight(.medium)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.trailing)
            }
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(UIColor.separator)),
                alignment: .bottom
            )
            
            // Main content
            Form {
                Section(header: Text("Meeting Details")) {
                    TextField("Meeting Title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Description (optional)", text: .constant(""))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section(header: Text("Participants")) {
                    ForEach(participants, id: \.self) { participant in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            Text(participant)
                            Spacer()
                            Button(action: {
                                participants.removeAll { $0 == participant }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .onDelete(perform: deleteParticipants)
                    
                    HStack {
                        TextField("Add participant", text: $newParticipant)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                addParticipant()
                            }
                        
                        Button(action: addParticipant) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newParticipant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
                Section(header: Text("Quick Start")) {
                    Button(action: createAndStartMeeting) {
                        HStack {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.white)
                            Text("Create & Start Recording")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button(action: createMeetingOnly) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.primary)
                            Text("Create Meeting Only")
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                Section(header: Text("Templates")) {
                    templateButtons
                }
            }
        }
        .onAppear {
            // Set default title with current timestamp if title is empty
            if title.isEmpty {
                title = generateTimestampTitle()
            }
        }
    }
    
    // MARK: - Template Buttons
    
    private var templateButtons: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { useTemplate("Team Standup", ["Team"]) }) {
                    templateButtonView("Team Standup", "person.3.fill")
                }
                
                Button(action: { useTemplate("Client Meeting", ["Client"]) }) {
                    templateButtonView("Client Meeting", "briefcase.fill")
                }
            }
            
            HStack {
                Button(action: { useTemplate("Project Review", ["Project Team"]) }) {
                    templateButtonView("Project Review", "folder.fill")
                }
                
                Button(action: { useTemplate("1-on-1", ["Manager"]) }) {
                    templateButtonView("1-on-1", "person.2.fill")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateTimestampTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HH'h'mm'm'ss's'"
        return formatter.string(from: Date())
    }
    
    private func templateButtonView(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func useTemplate(_ templateTitle: String, _ templateParticipants: [String]) {
        title = templateTitle
        participants = templateParticipants
    }
    
    private func addParticipant() {
        let participant = newParticipant.trimmingCharacters(in: .whitespacesAndNewlines)
        if !participant.isEmpty && !participants.contains(participant) {
            participants.append(participant)
            newParticipant = ""
        }
    }
    
    private func deleteParticipants(offsets: IndexSet) {
        participants.remove(atOffsets: offsets)
    }
    
    private func dismissView() {
        if let isPresented = isPresented {
            isPresented.wrappedValue = false
        } else {
            dismiss()
        }
    }
    
    private func createMeetingOnly() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        meetingStore.createMeeting(title: trimmedTitle, participants: participants)
        dismissView()
    }
    
        private func createAndStartMeeting() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        meetingStore.createMeeting(title: trimmedTitle, participants: participants)
        
        if let newMeeting = meetingStore.currentMeeting {
            // Dismiss the creation view first
            dismissView()
            
            // Then trigger the recording via callback
            onMeetingCreatedWithRecording?(newMeeting)
        }
    }
}

// MARK: - Preview

#Preview {
    MeetingCreationView()
        .environmentObject(MeetingStore())
} 