//
//  ContentView.swift
//  MeetingPen
//
//  Created by Sean Song on 7/5/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var meetingStore = MeetingStore()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            MeetingCreationView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("New Meeting")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .environmentObject(meetingStore)
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
