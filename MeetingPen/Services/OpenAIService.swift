import Foundation
import Combine

/// Service for integrating with OpenAI's API to generate meeting notes
class OpenAIService: ObservableObject {
    static let shared = OpenAIService()
    
    @Published var isGenerating = false
    @Published var generationError: Error?
    
    private let baseURL = "https://api.openai.com/v1"
    private let model = "gpt-4o-mini" // Using GPT-4o mini model (cost-effective and reliable)
    
    // Get API key from user settings
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
    }
    
    private init() {}
    
    /// Generate a brief AI summary using OpenAI O3 model
    /// - Parameters:
    ///   - meeting: The meeting data to generate summary from
    ///   - completion: Completion handler with generated summary or error
    func generateMeetingSummary(for meeting: Meeting, completion: @escaping (Result<String, Error>) -> Void) {
        print("🤖 [DEBUG] Starting meeting summary generation with OpenAI O3")
        
        guard !apiKey.isEmpty else {
            let error = OpenAIError.invalidAPIKey
            print("❌ [DEBUG] OpenAI API key not configured")
            completion(.failure(error))
            return
        }
        
        isGenerating = true
        generationError = nil
        
        // Prepare the summary prompt
        let prompt = createMeetingSummaryPrompt(for: meeting)
        print("🤖 [DEBUG] Generated summary prompt (\(prompt.count) characters)")
        
        // Create the request
        let request = createChatCompletionRequest(prompt: prompt)
        
        // Make the API call
        performAPICall(request: request) { [weak self] result in
            DispatchQueue.main.async {
                self?.isGenerating = false
                
                switch result {
                case .success(let summary):
                    print("✅ [DEBUG] Successfully generated meeting summary (\(summary.count) characters)")
                    completion(.success(summary))
                case .failure(let error):
                    print("❌ [DEBUG] Failed to generate meeting summary: \(error.localizedDescription)")
                    self?.generationError = error
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Generate detailed meeting notes using OpenAI O3 model
    /// - Parameters:
    ///   - meeting: The meeting data to generate notes from
    ///   - completion: Completion handler with generated notes or error
    func generateMeetingNotes(for meeting: Meeting, completion: @escaping (Result<String, Error>) -> Void) {
        print("🤖 [DEBUG] Starting meeting notes generation with OpenAI O3")
        
        guard !apiKey.isEmpty else {
            let error = OpenAIError.invalidAPIKey
            print("❌ [DEBUG] OpenAI API key not configured")
            completion(.failure(error))
            return
        }
        
        isGenerating = true
        generationError = nil
        
        // Prepare the prompt with meeting data
        let prompt = createMeetingNotesPrompt(for: meeting)
        print("🤖 [DEBUG] Generated prompt (\(prompt.count) characters)")
        
        // Create the request
        let request = createChatCompletionRequest(prompt: prompt)
        
        // Make the API call
        performAPICall(request: request) { [weak self] result in
            DispatchQueue.main.async {
                self?.isGenerating = false
                
                switch result {
                case .success(let notes):
                    print("✅ [DEBUG] Successfully generated meeting notes (\(notes.count) characters)")
                    completion(.success(notes))
                case .failure(let error):
                    print("❌ [DEBUG] Failed to generate meeting notes: \(error.localizedDescription)")
                    self?.generationError = error
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Create a focused prompt for meeting summary generation
    private func createMeetingSummaryPrompt(for meeting: Meeting) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        
        let transcription = meeting.transcriptData.fullText.isEmpty ? "No audio transcription available" : meeting.transcriptData.fullText
        let handwrittenNotes = meeting.handwritingData.allRecognizedText.isEmpty ? "No handwritten notes available" : meeting.handwritingData.allRecognizedText
        let duration = meeting.duration > 0 ? "\(Int(meeting.duration / 60)) minutes" : "Duration not recorded"
        
        // Get language instruction based on meeting language
        let languageInstruction = getLanguageInstruction(for: meeting.language)
        
        return """
        You are an expert meeting analyst. Create a concise, professional summary of this meeting.

        MEETING DATA:
        - Meeting Title: \(meeting.title)
        - Date & Time: \(dateFormatter.string(from: meeting.date))
        - Duration: \(duration)
        - Audio Transcription: \(transcription)
        - Handwritten Notes: \(handwrittenNotes)

        INSTRUCTIONS:
        Create a brief, executive-level summary (2-4 sentences) that captures:
        1. The main purpose/topic of the meeting
        2. Key decisions or outcomes
        3. Important next steps or action items

        Guidelines:
        - Keep it concise and professional
        - Focus on the most important information
        - Combine insights from both audio and handwritten sources
        - Use clear, business-appropriate language
        - If data is limited, focus on what is available

        \(languageInstruction)

        Generate only the summary text, no additional formatting or headers.
        """
    }
    
    /// Create a detailed prompt for meeting notes generation
    private func createMeetingNotesPrompt(for meeting: Meeting) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        
        let transcription = meeting.transcriptData.fullText.isEmpty ? "No audio transcription available" : meeting.transcriptData.fullText
        let handwrittenNotes = meeting.handwritingData.allRecognizedText.isEmpty ? "No handwritten notes available" : meeting.handwritingData.allRecognizedText
        let duration = meeting.duration > 0 ? "\(Int(meeting.duration / 60)) minutes" : "Duration not recorded"
        
        // Get language instruction based on meeting language
        let languageInstruction = getLanguageInstruction(for: meeting.language)
        
        return """
        You are an expert meeting notes generator. Your task is to create comprehensive, professional meeting notes from the provided meeting data.

        INPUT DATA:
        - Meeting Title: \(meeting.title)
        - Date & Time: \(dateFormatter.string(from: meeting.date))
        - Duration: \(duration)
        - Audio Transcription: \(transcription)
        - Handwritten Notes: \(handwrittenNotes)
        - Participants: Not specified

        INSTRUCTIONS:
        1. Analyze both the audio transcription and handwritten notes to understand the meeting content
        2. Create structured meeting notes with the following sections:
           - Executive Summary (2-3 sentences)
           - Key Discussion Points (bullet points)
           - Decisions Made (if any)
           - Action Items (with responsible parties if mentioned)
           - Next Steps (if discussed)
           - Additional Notes (miscellaneous important points)

        3. Guidelines:
           - Combine information from both audio and handwritten sources intelligently
           - Prioritize clarity and professionalism
           - Use proper formatting with headers and bullet points
           - If handwritten notes contain numbers, prices, or specific details, prioritize those over transcription
           - Handle incomplete or unclear data gracefully
           - Keep it concise but comprehensive
           - Use present tense for decisions and past tense for discussions

        4. If the input data is minimal or unclear, still provide a structured format with available information.

        \(languageInstruction)

        Generate professional meeting notes following this structure. Use markdown formatting for headers and bullet points.
        """
    }
    
    /// Get language-specific instruction for AI generation
    private func getLanguageInstruction(for language: MeetingLanguage) -> String {
        switch language {
        case .english:
            return "IMPORTANT: Generate all content in English."
        case .japanese:
            return "重要: すべてのコンテンツを日本語で生成してください。適切な敬語を使用し、ビジネス文書としての品質を保ってください。"
        case .chinese:
            return "重要：请用中文生成所有内容。使用正式的商务语言，确保专业性和准确性。"
        case .spanish:
            return "IMPORTANTE: Genere todo el contenido en español. Use un lenguaje profesional y apropiado para documentos comerciales."
        case .italian:
            return "IMPORTANTE: Genera tutto il contenuto in italiano. Usa un linguaggio professionale e appropriato per documenti aziendali."
        case .german:
            return "WICHTIG: Generieren Sie alle Inhalte auf Deutsch. Verwenden Sie eine professionelle Sprache, die für Geschäftsdokumente geeignet ist."
        case .french:
            return "IMPORTANT : Générez tout le contenu en français. Utilisez un langage professionnel approprié pour les documents commerciaux."
        }
    }
    
    /// Create a chat completion request for OpenAI API
    private func createChatCompletionRequest(prompt: String) -> URLRequest {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 4000,
            "temperature": 0.7,
            "top_p": 1.0,
            "frequency_penalty": 0.0,
            "presence_penalty": 0.0
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ [DEBUG] Failed to serialize request body: \(error)")
        }
        
        return request
    }
    
    /// Perform the API call to OpenAI
    private func performAPICall(request: URLRequest, completion: @escaping (Result<String, Error>) -> Void) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(OpenAIError.invalidResponse))
                return
            }
            
            print("🤖 [DEBUG] OpenAI API Response: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = "HTTP \(httpResponse.statusCode)"
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("❌ [DEBUG] OpenAI API Error Response: \(errorString)")
                }
                completion(.failure(OpenAIError.apiError(errorMessage)))
                return
            }
            
            guard let data = data else {
                completion(.failure(OpenAIError.noData))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                
                if let content = response.choices.first?.message.content {
                    completion(.success(content))
                } else {
                    completion(.failure(OpenAIError.noContent))
                }
            } catch {
                print("❌ [DEBUG] Failed to decode OpenAI response: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - OpenAI Response Models

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - OpenAI Errors

enum OpenAIError: Error, LocalizedError {
    case invalidAPIKey
    case invalidResponse
    case apiError(String)
    case noData
    case noContent
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "OpenAI API key is not configured. Please add your API key in Settings."
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        case .noData:
            return "No data received from OpenAI API"
        case .noContent:
            return "No content in OpenAI response"
        }
    }
} 