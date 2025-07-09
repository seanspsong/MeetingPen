import SwiftUI

struct MeetingSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var meetingStore: MeetingStore
    
    @State private var meeting: Meeting
    @State private var hasChanges = false
    
    let onSave: (Meeting) -> Void
    
    init(meeting: Meeting, onSave: @escaping (Meeting) -> Void) {
        self._meeting = State(initialValue: meeting)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                languageSection
                
                settingsInfoSection
            }
            .navigationTitle("Meeting Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!hasChanges)
                }
            }
        }
    }
    
    // MARK: - Language Selection Section
    private var languageSection: some View {
        Section(header: Text("Language Settings")) {
            ForEach(MeetingLanguage.allCases, id: \.self) { language in
                HStack {
                    Text(language.flag)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.displayName)
                            .font(.body)
                        
                        Text("Audio & Handwriting Recognition")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if meeting.language == language {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if meeting.language != language {
                        meeting.language = language
                        hasChanges = true
                        
                        // Persist the language setting globally
                        Task {
                            await SpeechRecognitionService.shared.configureLanguage(language.speechRecognitionLocale)
                        }
                        print("💾 [SETTINGS] Language changed to: \(language.displayName)")
                    }
                }
            }
        }
    }
    
    // MARK: - Settings Information Section
    private var settingsInfoSection: some View {
        Section(header: Text("About Language Settings")) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Audio Transcription", systemImage: "waveform")
                    .foregroundColor(.blue)
                Text("Speech recognition will be optimized for the selected language")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Handwriting Recognition", systemImage: "pencil")
                    .foregroundColor(.green)
                Text("Handwritten text will be recognized using language-specific models")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Current Selection", systemImage: "gear")
                    .foregroundColor(.orange)
                HStack {
                    Text(meeting.language.flag)
                    Text(meeting.language.displayName)
                        .fontWeight(.medium)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Helper Methods
    private func saveChanges() {
        if hasChanges {
            var updatedMeeting = meeting
            updatedMeeting.updateLastModified()
            onSave(updatedMeeting)
        }
        dismiss()
    }
}

// MARK: - Preview
struct MeetingSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingSettingsView(
            meeting: Meeting(
                title: "Weekly Team Meeting",
                participants: ["Alice", "Bob", "Charlie"],
                language: .english
            ),
            onSave: { _ in }
        )
        .environmentObject(MeetingStore())
    }
} 