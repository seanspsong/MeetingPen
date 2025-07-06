//
//  MeetingPenApp.swift
//  MeetingPen
//
//  Created by Sean Song on 7/5/25.
//

import SwiftUI

@main
struct MeetingPenApp: App {
    // Initialize services early to request permissions at app launch
    @StateObject private var audioRecordingService = AudioRecordingService.shared
    @StateObject private var speechRecognitionService = SpeechRecognitionService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioRecordingService)
                .environmentObject(speechRecognitionService)
        }
    }
}
