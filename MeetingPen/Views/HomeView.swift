import SwiftUI

struct HomeView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @State private var searchText = ""
    @State private var showingMeetingDetail = false
    @State private var selectedMeeting: Meeting?
    @State private var showingNewMeeting = false
    
    var filteredMeetings: [Meeting] {
        meetingStore.searchMeetings(query: searchText)
    }
    
    var body: some View {
        NavigationView {
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
        }
        .sheet(isPresented: $showingNewMeeting) {
            MeetingCreationView(isPresented: $showingNewMeeting)
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
    
    // MARK: - Meetings List
    
    private var meetingsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredMeetings.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredMeetings) { meeting in
                        MeetingRowView(meeting: meeting)
                            .onTapGesture {
                                selectedMeeting = meeting
                            }
                    }
                }
            }
            .padding(.horizontal)
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

struct MeetingRowView: View {
    let meeting: Meeting
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        Label(meeting.formattedDate, systemImage: "calendar")
                        
                        if meeting.duration > 0 {
                            Label(meeting.formattedDuration, systemImage: "clock")
                        }
                        
                        if !meeting.participants.isEmpty {
                            Label("\(meeting.participants.count) participants", systemImage: "person.2")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Recording indicator
                if meeting.isRecording {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 1).repeatForever(), value: meeting.isRecording)
                        
                        Text("Recording")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Summary
            if !meeting.summary.isEmpty {
                Text(meeting.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Action Items Preview
            if !meeting.actionItems.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("\(meeting.actionItems.count) action items")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(MeetingStore())
} 