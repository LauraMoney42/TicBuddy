// TicBuddy — ClaudeService.swift
// Handles all communication with the Anthropic Claude API.
// Uses claude-3-5-haiku for fast, affordable chat responses.

import Foundation

// MARK: - Message Model

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}

// MARK: - API Request/Response Models
// Matches POST /api/tictalk proxy format: { messages, systemPrompt } → { response }

private struct TicTalkRequest: Encodable {
    let messages: [ProxyMessage]
    let systemPrompt: String
}

private struct ProxyMessage: Encodable {
    let role: String
    let content: String
}

private struct TicTalkResponse: Decodable {
    let response: String
}

// MARK: - Tic Log Intent (parsed from chat)

struct TicLogIntent {
    var category: TicCategory
    var typeName: String
    var outcome: TicOutcome
    var count: Int
}

// MARK: - ClaudeService

@MainActor
class ClaudeService: ObservableObject {
    // Routing: all requests go through the Railway proxy /api/tictalk endpoint.
    // The proxy holds the Anthropic API key server-side — no key needed on device.
    // AUTH_TOKEN is a shared secret (Bearer) to prevent unauthorized proxy access.
    private let baseURL = (ProcessInfo.processInfo.environment["PROXY_BASE_URL"]
        ?? "https://YOUR_RAILWAY_URL_HERE") + "/api/tictalk"
    private let authToken = ProcessInfo.processInfo.environment["AUTH_TOKEN"]
        ?? "dev-token"

    // MARK: - System Prompt Builder

    func buildSystemPrompt(for profile: UserProfile) -> String {
        let phase = profile.recommendedPhase

        // Privacy: tic categories only (e.g. "motor, vocal"), not specific descriptions.
        // User name and age are NOT sent to the API.
        let ticCategories: String = {
            let cats = Set(profile.primaryTicCategories.map { $0 == .motor ? "motor" : "vocal" })
            return cats.isEmpty ? "motor and/or vocal" : cats.sorted().joined(separator: " and ")
        }()

        // Age-based tone: adjust language complexity without sending age to API
        let toneLine: String = {
            switch profile.age {
            case ..<10: return "Use very simple words and short sentences. Lots of emojis! Max 2 sentences per reply."
            case 10..<13: return "Use friendly, encouraging language. Emojis are great. 3-4 sentences per reply."
            case 13..<17: return "Friendly but slightly more mature tone. 4-5 sentences per reply."
            default:     return "Supportive peer tone. Clear and concise. 4-6 sentences per reply."
            }
        }()

        // Awareness-level calibration: adjust coaching focus
        let awarenessGuidance: String = {
            switch profile.ticAwarenessLevel {
            case 1...2: return "This user has LOW awareness of their tics. Spend extra time on noticing practice and celebrating every small awareness win. Don't rush to competing responses."
            case 3: return "This user has moderate awareness. Balance noticing practice with introducing competing responses as appropriate for their phase."
            case 4...5: return "This user has HIGH awareness. They can move quickly through phases and jump into competing response practice with confidence."
            default: return "Balance noticing practice with competing responses as appropriate for their phase."
            }
        }()

        return """
        You are TicBuddy, a warm, encouraging, and fun AI companion for someone who has Tourette Syndrome and is working on CBIT (brain training for tics).

        PERSONALITY:
        - Speak like a friendly coach who is also a kid's best friend
        - \(toneLine)
        - Be VERY encouraging and positive — every effort is celebrated
        - Never make the user feel bad about their tics — normalize and celebrate awareness

        COACHING CALIBRATION:
        - \(awarenessGuidance)

        CURRENT CBIT PHASE: \(phase.title)
        PHASE GOAL: \(phase.goalText)
        TIC CATEGORIES: The user has \(ticCategories) tics

        PROGRAM RULES:
        \(phase == .week1Awareness ? """
        - We are in WEEK 1. The ONLY goal is to NOTICE tics. Do NOT suggest competing responses yet.
        - Celebrate every tic that gets noticed or logged
        - Explain the premonitory urge (the feeling before the tic) in simple terms: "That feeling you get RIGHT before the tic — like a tickle or pressure — is called the premonitory urge. Noticing it is your first superpower!"
        """ : buildCompetingResponseGuidance(for: profile))

        WHEN THE USER MENTIONS A TIC IN CHAT:
        - Celebrate that they noticed it!
        - Ask if they want to add it to their tic log
        - If yes, extract: tic type, whether they noticed/caught/redirected it
        - Respond with the tag [LOG_TIC: type=<ticType>, outcome=<noticed|caught|redirected|ticHappened>]
          so the app can automatically log it to the calendar

        EDUCATIONAL TOPICS (explain simply when asked):
        - Tourette Syndrome: "Tourette's means your brain sometimes sends signals your body didn't ask for. That's what causes tics. It's not your fault and you can't always control it!"
        - CBIT: "CBIT is like a superpower training program. We train your brain to notice tics and learn new moves!"
        - Neuroplasticity: "Your brain can change and grow new paths — like a trail in the forest. Every time you practice, the path gets stronger!"
        - Premonitory urge: "That feeling right before a tic — like a tickle or pressure — that's your early warning system. It's actually a superpower!"

        Keep responses SHORT (2-4 sentences max) unless explaining something educational.
        Always end with encouragement or a question to keep the conversation going.
        """
    }

    // MARK: - Competing Response Guidance

    private func buildCompetingResponseGuidance(for profile: UserProfile) -> String {
        let responses = CompetingResponseLibrary.responses(for: profile.primaryTics)
        if responses.isEmpty {
            return "- We are past week 1. Encourage competing responses: tense muscles opposing the tic, breathe slowly through nose, hold for ~60 seconds. Celebrate every attempt!"
        }
        let crList = responses.map { "  • \($0.forTicType): \($0.title) — \($0.kidFriendlyTip)" }.joined(separator: "\n")
        return """
        - We are past week 1. Encourage competing responses.
        - SPECIFIC competing responses for this user's tics:
        \(crList)
        - When describing a competing response, use the kid-friendly tip language above
        - Celebrate every successful redirection enormously — it means their brain is literally rewiring!
        - If they fail to redirect: "That's okay! Your brain is still learning. The fact that you noticed is already amazing! 💙"
        """
    }

    // MARK: - Send Message

    func sendMessage(
        userMessage: String,
        conversationHistory: [ChatMessage],
        profile: UserProfile
    ) async throws -> String {
        let systemPrompt = buildSystemPrompt(for: profile)

        // Build message history (last 20 messages to keep context window reasonable)
        let recentHistory = conversationHistory.suffix(20)
        let proxyMessages = recentHistory.map { ProxyMessage(role: $0.role.rawValue, content: $0.content) }
            + [ProxyMessage(role: "user", content: userMessage)]

        // Build proxy request: { messages, systemPrompt }
        let request = TicTalkRequest(messages: proxyMessages, systemPrompt: systemPrompt)

        guard let url = URL(string: baseURL) else { throw ClaudeError.apiError("Invalid proxy URL") }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw ClaudeError.apiError("Status \(statusCode): \(String(data: data, encoding: .utf8) ?? "unknown")")
        }

        // Proxy returns { response: string }
        let decoded = try JSONDecoder().decode(TicTalkResponse.self, from: data)
        return decoded.response
    }

    // MARK: - Parse Tic Log Intent from Response

    /// Parses [LOG_TIC: type=X, outcome=Y] tags from Claude's response
    func parseTicLogIntent(from response: String) -> TicLogIntent? {
        guard let range = response.range(of: #"\[LOG_TIC: type=([^,]+), outcome=([^\]]+)\]"#, options: .regularExpression) else {
            return nil
        }
        let tag = String(response[range])

        // Extract type
        guard let typeRange = tag.range(of: #"type=([^,\]]+)"#, options: .regularExpression) else { return nil }
        let typeStr = String(tag[typeRange]).replacingOccurrences(of: "type=", with: "").trimmingCharacters(in: .whitespaces)

        // Extract outcome
        guard let outcomeRange = tag.range(of: #"outcome=([^\]]+)"#, options: .regularExpression) else { return nil }
        let outcomeStr = String(tag[outcomeRange]).replacingOccurrences(of: "outcome=", with: "").trimmingCharacters(in: .whitespaces)

        let outcome: TicOutcome
        switch outcomeStr.lowercased() {
        case "caught": outcome = .caught
        case "redirected": outcome = .redirected
        case "tichappened", "tic_happened": outcome = .ticHappened
        default: outcome = .noticed
        }

        // Determine category from type string
        let vocalKeywords = ["throat", "sniff", "grunt", "cough", "word", "hum", "vocal"]
        let isVocal = vocalKeywords.contains { typeStr.lowercased().contains($0) }

        return TicLogIntent(
            category: isVocal ? .vocal : .motor,
            typeName: typeStr,
            outcome: outcome,
            count: 1
        )
    }

    /// Strips the [LOG_TIC: ...] tag from response text before displaying
    func cleanResponse(_ response: String) -> String {
        response.replacingOccurrences(of: #"\[LOG_TIC:[^\]]+\]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum ClaudeError: Error, LocalizedError {
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .apiError(let msg): return "API Error: \(msg)"
        }
    }
}
