# MeetingPen 📝🎙️

An intelligent meeting companion app for iPad that combines audio recording, handwritten note-taking, and AI-powered summarization to create comprehensive meeting documentation.

## 🚀 Overview

MeetingPen transforms how you capture and process meeting information by seamlessly integrating:
- **Real-time audio recording** with high-quality transcription
- **Natural handwriting input** using Apple Pencil with text recognition
- **AI-powered summarization** via OpenAI API for professional meeting notes
- **Intelligent synthesis** of audio transcripts and handwritten notes

## ✨ Key Features

### 📱 Core Functionality
- **Multi-modal Input**: Simultaneous audio recording and handwriting
- **Real-time Transcription**: Live speech-to-text conversion
- **Handwriting Recognition**: Convert handwritten notes to searchable text
- **AI Summarization**: Generate structured meeting summaries with key points, action items, and decisions
- **Export Options**: PDF, text, and formatted reports

### 🎯 iPad-Optimized Experience
- **Apple Pencil Integration**: Pressure-sensitive writing with natural feel
- **Split-screen Interface**: Audio controls alongside writing canvas
- **Gesture Support**: Pinch-to-zoom, palm rejection, and multi-touch navigation
- **Landscape/Portrait Modes**: Optimized layouts for different orientations

### 🤖 AI-Powered Intelligence
- **Context-Aware Summarization**: Understands meeting flow and participant roles
- **Action Item Extraction**: Automatically identifies tasks and deadlines
- **Key Decision Highlighting**: Surfaces important decisions and conclusions
- **Participant Recognition**: Identifies speakers and attributes comments

## 🛠️ Technical Stack

### iOS Development
- **Language**: Swift 5.x
- **Framework**: SwiftUI for modern, declarative UI
- **Minimum iOS**: 15.0 (iPad-focused)
- **Architecture**: MVVM with Combine for reactive programming

### Core Technologies
- **Audio Processing**: AVFoundation for recording and playback
- **Speech Recognition**: Speech framework for real-time transcription
- **Handwriting Recognition**: PencilKit + Vision framework for text recognition
- **AI Integration**: OpenAI API for GPT-4 powered summarization
- **Data Storage**: Core Data for local persistence, CloudKit for sync

### External Services
- **OpenAI API**: GPT-4 for meeting summarization and analysis
- **Speech Services**: iOS native speech recognition with fallback to cloud services
- **Cloud Storage**: iCloud integration for document sync across devices

## 🎨 User Experience Design

### Interface Layout
```
┌─────────────────────────────────────────────────────────────┐
│ Meeting Title    [🎙️ Record] [⏸️ Pause] [⏹️ Stop]    Settings │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Audio Waveform Visualization                               │
│  Live Transcription Preview                                 │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                                                             │
│              Handwriting Canvas                             │
│              (Apple Pencil Input)                           │
│                                                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### User Flow
1. **Meeting Setup**: Create new meeting, set title and participants
2. **Recording Phase**: Start audio recording + handwriting simultaneously
3. **Live Processing**: Real-time transcription and note digitization
4. **AI Analysis**: Post-meeting summarization and action item extraction
5. **Review & Export**: Edit summary, export in multiple formats

## 🔧 Development Roadmap

### Phase 1: Core Recording (MVP)
- [ ] Audio recording with waveform visualization
- [ ] Basic handwriting canvas with Apple Pencil support
- [ ] Simple note saving and retrieval
- [ ] Basic transcription integration

### Phase 2: AI Integration
- [ ] OpenAI API integration for summarization
- [ ] Handwriting recognition with Vision framework
- [ ] Combined transcript + notes processing
- [ ] Action item extraction

### Phase 3: Advanced Features
- [ ] Multi-participant voice recognition
- [ ] Real-time collaboration features
- [ ] Advanced export options (PDF, Word, etc.)
- [ ] Meeting templates and customization

### Phase 4: Cloud & Sync
- [ ] iCloud synchronization
- [ ] Cross-device access
- [ ] Meeting sharing and collaboration
- [ ] Advanced search and organization

## 📋 Requirements

### Hardware
- iPad (9th generation or later) with Apple Pencil support
- Minimum 64GB storage recommended
- Microphone access required

### Software
- iOS 15.0 or later
- Internet connection for AI processing
- OpenAI API key (user-provided or subscription model)

## 🔐 Privacy & Security

- **Local Processing**: Audio and handwriting processed locally when possible
- **Encrypted Storage**: All meeting data encrypted at rest
- **API Security**: Secure communication with OpenAI API
- **User Control**: Users own their data, easy export/deletion options

## 🚀 Getting Started

### For Developers
1. Clone the repository
2. Open `MeetingPen.xcodeproj` in Xcode
3. Configure OpenAI API key in settings
4. Build and run on iPad simulator or device

### For Users
1. Install from App Store (when released)
2. Grant microphone and storage permissions
3. Configure OpenAI API key or subscribe to service
4. Start your first meeting!

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines for details on how to submit pull requests, report issues, and suggest improvements.

---

**MeetingPen** - Transforming meetings into actionable insights, one note at a time. ✨ 