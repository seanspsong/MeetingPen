import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @AppStorage("userName") private var userName = ""
    @AppStorage("openAIAPIKey") private var openAIAPIKey = ""
    @AppStorage("autoRecognition") private var autoRecognition = true
    @AppStorage("recognitionDelay") private var recognitionDelay = 1.0
    @AppStorage("minimumConfidence") private var minimumConfidence = 0.3
    @AppStorage("audioQuality") private var audioQuality = "high"
    @AppStorage("allowFingerDrawing") private var allowFingerDrawing = false
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("showDebugView") private var showDebugView = false
    
    @State private var showingAPIKeyAlert = false
    @State private var showingAbout = false
    
    var body: some View {
        Form {
            // User Profile
            Section(header: Text("Profile")) {
                TextField("Your Name", text: $userName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // AI Settings
            Section(header: Text("AI Configuration")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")
                        .font(.headline)
                    
                    SecureField("Enter API Key", text: $openAIAPIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if openAIAPIKey.isEmpty {
                        Text("Required for AI-powered meeting summaries")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Button("Get API Key") {
                        showingAPIKeyAlert = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // Handwriting Recognition
            Section(header: Text("Handwriting Recognition")) {
                Toggle("Auto Recognition", isOn: $autoRecognition)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recognition Delay: \(recognitionDelay, specifier: "%.1f")s")
                    Slider(value: $recognitionDelay, in: 0.5...3.0, step: 0.1)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Minimum Confidence: \(minimumConfidence, specifier: "%.1f")")
                    Slider(value: $minimumConfidence, in: 0.1...0.9, step: 0.1)
                }
                
                Toggle("Allow Finger Drawing", isOn: $allowFingerDrawing)
                
                Toggle("Show Debug View", isOn: $showDebugView)
            }
            
            // Audio Settings
            Section(header: Text("Audio")) {
                Picker("Audio Quality", selection: $audioQuality) {
                    Text("Low").tag("low")
                    Text("Medium").tag("medium")
                    Text("High").tag("high")
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
            }
            
            // Storage & Sync
            Section(header: Text("Storage")) {
                HStack {
                    Text("Total Meetings")
                    Spacer()
                    Text("\(meetingStore.totalMeetings)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Total Recording Time")
                    Spacer()
                    Text(formatDuration(meetingStore.totalRecordingTime))
                        .foregroundColor(.secondary)
                }
                
                Button("Export All Data") {
                    exportAllData()
                }
                .foregroundColor(.blue)
                
                Button("Clear All Data") {
                    clearAllData()
                }
                .foregroundColor(.red)
            }
            
            // About
            Section(header: Text("About")) {
                Button("About MeetingPen") {
                    showingAbout = true
                }
                .foregroundColor(.blue)
                
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("OpenAI API Key", isPresented: $showingAPIKeyAlert) {
            Button("Get Key") {
                if let url = URL(string: "https://platform.openai.com/api-keys") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You need an OpenAI API key to use AI-powered meeting summaries. Visit the OpenAI website to get your key.")
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func exportAllData() {
        // TODO: Implement data export
        print("Exporting all data...")
    }
    
    private func clearAllData() {
        // TODO: Implement with confirmation alert
        print("Clearing all data...")
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 16) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("MeetingPen")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("About")
                        .font(.headline)
                    
                    Text("MeetingPen is an intelligent meeting companion that combines audio recording, handwritten note-taking, and AI-powered summarization to create comprehensive meeting documentation.")
                        .font(.body)
                    
                    Text("Features")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "mic.fill", text: "High-quality audio recording")
                        FeatureRow(icon: "pencil.tip", text: "Apple Pencil handwriting recognition")
                        FeatureRow(icon: "brain.head.profile", text: "AI-powered meeting summaries")
                        FeatureRow(icon: "checkmark.circle", text: "Automatic action item extraction")
                        FeatureRow(icon: "square.and.arrow.up", text: "Professional export options")
                    }
                    
                    Text("Privacy")
                        .font(.headline)
                    
                    Text("Your meeting data is processed locally when possible. AI features require internet connectivity but your data remains secure and private.")
                        .font(.body)
                    
                    Text("Support")
                        .font(.headline)
                    
                    Button("Contact Support") {
                        if let url = URL(string: "mailto:support@meetingpen.app") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("About")
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

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(MeetingStore())
} 