# MeetingPen 📝🎙️

An intelligent meeting companion app for iPad that combines audio recording, handwritten note-taking, and AI-powered summarization to create comprehensive meeting documentation.

## 🚀 Overview

MeetingPen transforms how you capture and process meeting information by seamlessly integrating:
- **Real-time audio recording** with high-quality transcription
- **Natural handwriting input** using Apple Pencil with text recognition
- **AI-powered summarization** via OpenAI API for professional meeting notes
- **Intelligent synthesis** of audio transcripts and handwritten notes
- **Comprehensive structured data storage** for advanced analysis and insights

## ✨ Key Features

### 📱 Core Functionality
- **Multi-modal Input**: Simultaneous audio recording and handwriting
- **Real-time Transcription**: Live speech-to-text conversion with speaker identification
- **Handwriting Recognition**: Convert handwritten notes to searchable text with OCR
- **AI Summarization**: Generate structured meeting summaries with key points, action items, and decisions
- **Structured Data Model**: Comprehensive storage for audio, transcripts, handwriting, and AI analysis
- **Export Options**: PDF, text, and formatted reports

### 🎯 iPad-Optimized Experience
- **Apple Pencil Integration**: Pressure-sensitive writing with natural feel
- **Split-screen Interface**: Audio controls alongside writing canvas
- **Gesture Support**: Pinch-to-zoom, palm rejection, and multi-touch navigation
- **Landscape/Portrait Modes**: Optimized layouts for different orientations
- **Card-based Grid Layout**: Intuitive meeting organization with 4 cards per row

### 🤖 AI-Powered Intelligence
- **Context-Aware Summarization**: Understands meeting flow and participant roles
- **Action Item Extraction**: Automatically identifies tasks and deadlines with priority tracking
- **Key Decision Highlighting**: Surfaces important decisions and conclusions
- **Participant Recognition**: Identifies speakers and attributes comments
- **Entity Extraction**: Automatic identification of people, dates, locations, and topics
- **Sentiment Analysis**: Meeting tone and engagement insights

## 🏗️ Data Architecture

### Comprehensive Meeting Data Model
```swift
Meeting {
    // Basic Information
    id, title, date, duration, participants, tags, location
    status: .created → .recording → .processing → .completed → .archived
    
    // Audio Data
    audioData: {
        segments: [AudioSegment] // Multi-part recordings with timestamps
        format: M4A/MP3/WAV/AAC support
        qualityScores: Confidence tracking
        fileManagement: Automatic cleanup
    }
    
    // Transcript Data  
    transcriptData: {
        segments: [TranscriptSegment] // Word-level timestamps
        speakers: [Speaker] // Voice identification
        fullText: Combined transcript
        confidence: Recognition accuracy
        language: Auto-detection
    }
    
    // Handwriting Data
    handwritingData: {
        textSegments: [OCRText] // Recognized text with bounding boxes
        drawings: [PKDrawing] // Original PencilKit data
        pages: [HandwritingPage] // Page-based organization
        allRecognizedText: Searchable combined text
    }
    
    // AI Analysis
    aiAnalysis: {
        summary: Meeting overview
        keyDecisions: Important conclusions
        actionItems: [ActionItem] // With priority, status, assignee
        insights: [Insight] // AI-generated observations
        entities: [Entity] // Extracted people, dates, locations
        sentiment: Overall meeting tone
    }
}
```

## 🛠️ Technical Stack

### iOS Development
- **Language**: Swift 5.x
- **Framework**: SwiftUI for modern, declarative UI
- **Minimum iOS**: 26.0 (iPad-focused, latest iOS features)
- **Architecture**: MVVM with Combine for reactive programming

### Core Technologies
- **Audio Processing**: AVFoundation for multi-segment recording and playback
- **Speech Recognition**: Speech framework for real-time transcription with speaker identification
- **Handwriting Recognition**: PencilKit + Vision framework for OCR text recognition
- **AI Integration**: OpenAI API for GPT-4 powered summarization and analysis
- **Data Storage**: Comprehensive Codable models with file management and versioning

### Data Management
- **Structured Storage**: Nested data models for audio, transcripts, handwriting, and AI analysis
- **File Management**: Automatic cleanup and integrity checking
- **Version Control**: Migration-ready data structure
- **Search Optimization**: Full-text search across all content types
- **Export Ready**: Multiple format support (JSON, PDF, text)

### External Services
- **OpenAI API**: GPT-4 for meeting summarization and analysis
- **Speech Services**: iOS native speech recognition with confidence scoring
- **Vision Framework**: On-device handwriting recognition and OCR

## 🎨 User Experience Design

### Interface Layout
```
┌─────────────────────────────────────────────────────────────┐
│ Meeting Title    [🎙️ Record] [⏸️ Pause] [⏹️ Stop]    Settings │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Audio Waveform Visualization & Live Transcription         │
│  [Speaker Detection] [Quality Metrics] [Debug Toggle]      │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                     │                                       │
│   Hand Notes Stats  │         Handwriting Canvas            │
│   • OCR Text Count  │         (Apple Pencil Input)          │
│   • Recognition %   │         [Drawing Tools] [Clear]       │
│   • Last Update     │         [OCR Recognition]             │
│                     │                                       │
└─────────────────────────────────────────────────────────────┘
```

### User Flow
1. **Meeting Setup**: Create new meeting with auto-generated timestamps
2. **Recording Phase**: Start audio recording + handwriting simultaneously
3. **Live Processing**: Real-time transcription and OCR text recognition
4. **Data Integration**: Structured storage of all meeting components
5. **AI Analysis**: Post-meeting summarization and action item extraction
6. **Review & Export**: Edit summary, export in multiple formats

## 📈 Development Progress

### ✅ Completed Features (Phase 1-2)
- **Core Recording Infrastructure**
  - Multi-segment audio recording with quality tracking
  - Real-time speech transcription with speaker identification
  - Handwriting canvas with Apple Pencil integration
  - OCR text recognition with confidence scoring
  
- **Comprehensive Data Model**
  - Structured storage for audio, transcripts, handwriting, AI analysis
  - Full Codable support with version control
  - File management and automatic cleanup
  - Meeting lifecycle status tracking
  
- **User Interface**
  - Split-screen recording interface with floating controls
  - Card-based meeting grid (4 per row)
  - Debug view toggle for development
  - Optimized layout for handwriting and audio

- **Data Integration**
  - Real-time handwriting recognition persistence
  - Combined audio and handwriting workflow
  - Structured meeting organization
  - Export-ready data architecture

### 🚧 In Progress (Phase 3)
- [ ] OpenAI API integration for AI summarization
- [ ] Action item extraction and management
- [ ] Entity recognition and tagging
- [ ] Advanced export options (PDF, Word, etc.)

### 📋 Planned Features (Phase 4)
- [ ] Multi-participant voice recognition
- [ ] Real-time collaboration features  
- [ ] iCloud synchronization
- [ ] Cross-device access and sharing
- [ ] Advanced search and organization
- [ ] Meeting templates and customization

## 📝 Git Commit History

```
1ae66d7 - Implement comprehensive structured data model for meeting storage
ef8ca05 - Enhance meeting creation with auto-generated timestamps and proper view lifecycle
3375b76 - Add top-right save and cancel buttons to meeting recording view
c8bed2c - Fix handwriting recognition persistence - preserve existing text when clearing canvas
7d59136 - Streamline Hand Notes interface with floating stats toggle
15982ca - Optimize right panel layout with 60/40 split and enhanced space utilization
df43764 - Redesign right panel layout with vertical Hand Notes and canvas split
5dceea6 - Complete floating control bar redesign and debug view repositioning
831e845 - Move recording controls to left audio section, drawing tools to right handwriting section
8b9169b - Refactor recording view layout: move debug view and add Hand Notes section
9cf19a5 - Add debug view toggle setting (default OFF) - cleaner UI with optional debug info when needed
3673ffe - Implement simplified recording/playback interface with mutual exclusion logic
1b25f6e - Convert HomeView to card-based grid layout with 4 cards per row
9ab1916 - Fix handwriting recognition cache issues and enhance debug visibility
66e81e6 - Refactor UI to full-width layout and optimize handwriting recognition
ebd152f - Implement comprehensive UI structure for MeetingPen
e576160 - Implement comprehensive handwriting recognition system
33e3e17 - Initial commit: MeetingPen iOS app with comprehensive documentation
```

## 📋 Requirements

### Hardware
- iPad (9th generation or later) with Apple Pencil support
- Minimum 64GB storage recommended
- Microphone access required

### Software
- iOS 26.0 or later (latest iOS features)
- Internet connection for AI processing
- OpenAI API key (user-provided or subscription model)

## 🔐 Privacy & Security

- **Local Processing**: Audio and handwriting processed locally when possible
- **Encrypted Storage**: All meeting data encrypted at rest with structured models
- **API Security**: Secure communication with OpenAI API
- **User Control**: Users own their data, easy export/deletion options
- **Data Integrity**: File checksums and validation for audio segments

## 🚀 Getting Started

### For Developers
1. Clone the repository: `git clone https://github.com/seanspsong/MeetingPen.git`
2. Open `MeetingPen.xcodeproj` in Xcode 15+
3. Configure OpenAI API key in settings (when AI features are implemented)
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

**MeetingPen** - Transforming meetings into actionable insights with comprehensive data capture and AI-powered analysis. ✨ 