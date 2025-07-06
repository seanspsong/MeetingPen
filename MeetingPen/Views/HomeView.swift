import SwiftUI

struct HomeView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @State private var searchText = ""
    @State private var showingMeetingDetail = false
    @State private var selectedMeeting: Meeting?
    @State private var showingNewMeeting = false
    @State private var showingRecording = false
    @State private var meetingToRecord: Meeting?
    
    var filteredMeetings: [Meeting] {
        meetingStore.searchMeetings(query: searchText)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Search Bar
                searchBar
                
                // Meetings List
                meetingsList
                
                // Quick Action Button
                quickActionButton
            }
        }
        .navigationTitle("MeetingPen")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingNewMeeting = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingNewMeeting) {
            MeetingCreationView(
                isPresented: $showingNewMeeting,
                onMeetingCreatedWithRecording: { meeting in
                    meetingToRecord = meeting
                    showingRecording = true
                }
            )
        }
        .fullScreenCover(isPresented: $showingRecording) {
            if let meeting = meetingToRecord {
                MeetingRecordingView(meeting: meeting, isPresented: $showingRecording, shouldStartRecording: true)
            }
        }
        .sheet(item: $selectedMeeting) { meeting in
            MeetingDetailView(meeting: meeting)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Ready to capture your next meeting?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Stats
                HStack(spacing: 20) {
                    StatView(title: "Total", value: "\(meetingStore.totalMeetings)")
                    StatView(title: "This Week", value: "\(meetingStore.meetingsThisWeek)")
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search meetings...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Meetings Grid
    
    private var meetingsList: some View {
        ScrollView {
            if filteredMeetings.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                    ForEach(filteredMeetings) { meeting in
                        MeetingCardView(meeting: meeting)
                            .onTapGesture {
                                selectedMeeting = meeting
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .refreshable {
            // Refresh meetings from server/storage
            // For now, just a placeholder
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Meetings Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start your first meeting to capture notes and audio")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Create First Meeting") {
                showingNewMeeting = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Quick Action Button
    
    private var quickActionButton: some View {
        HStack {
            Spacer()
            
            Button(action: { showingNewMeeting = true }) {
                HStack {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                    Text("Start New Meeting")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(16)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Supporting Views

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct MeetingCardView: View {
    let meeting: Meeting
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and recording indicator
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(meeting.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    // Recording indicator
                    if meeting.isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 1).repeatForever(), value: meeting.isRecording)
                    }
                }
                
                // Date
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(meeting.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Summary
            if !meeting.summary.isEmpty {
                Text(meeting.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            } else {
                Text("No summary available")
                    .font(.caption)
                    .foregroundColor(Color(.systemGray3))
                    .italic()
            }
            
            Spacer()
            
            // Bottom info
            VStack(alignment: .leading, spacing: 6) {
                // Duration and participants
                HStack(spacing: 12) {
                    if meeting.duration > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(meeting.formattedDuration)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if !meeting.participants.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.caption2)
                            Text("\(meeting.participants.count)")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                // Action Items
                if !meeting.aiAnalysis.actionItems.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        Text("\(meeting.aiAnalysis.actionItems.count) action items")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: 200)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(MeetingStore())
} 