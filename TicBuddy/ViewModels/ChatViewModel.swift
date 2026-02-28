// TicBuddy — ChatViewModel.swift
// Manages chat state, message history, and tic auto-logging from chat.

import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var pendingTicLog: TicLogIntent? = nil
    @Published var lastLoggedEntry: TicEntry? = nil
    @Published var errorMessage: String? = nil

    private let claudeService = ClaudeService()
    private let dataService: TicDataService

    init(dataService: TicDataService = .shared) {
        self.dataService = dataService
        loadHistory()
        if messages.isEmpty {
            addWelcomeMessage()
        }
    }

    // MARK: - Welcome Message

    private func addWelcomeMessage() {
        let profile = dataService.userProfile
        let phase = profile.recommendedPhase
        let welcome = ChatMessage(
            role: .assistant,
            content: """
            Hi \(profile.name.isEmpty ? "there" : profile.name)! 👋 I'm TicBuddy, your tic-fighting sidekick! 🦸

            \(phase.goalText)

            You can tell me about any tics you notice, and I'll help you log them. Or just chat — I'm here! 😊

            What's going on today?
            """
        )
        messages.append(welcome)
    }

    // MARK: - Send Message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        errorMessage = nil

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        isLoading = true

        Task {
            do {
                let response = try await claudeService.sendMessage(
                    userMessage: text,
                    conversationHistory: messages.dropLast(), // exclude the message we just added
                    profile: dataService.userProfile
                )

                // Check for auto-log intent
                if let intent = claudeService.parseTicLogIntent(from: response) {
                    pendingTicLog = intent
                    let logged = dataService.quickLog(intent: intent)
                    lastLoggedEntry = logged
                }

                let cleanedResponse = claudeService.cleanResponse(response)
                let assistantMessage = ChatMessage(role: .assistant, content: cleanedResponse)
                messages.append(assistantMessage)

                saveHistory()
                dataService.checkAndAdvancePhase()

            } catch {
                errorMessage = error.localizedDescription
                let errorMsg = ChatMessage(
                    role: .assistant,
                    content: "Oops! I had a little glitch. 🤖 Try again? \(error.localizedDescription)"
                )
                messages.append(errorMsg)
            }

            isLoading = false
        }
    }

    // MARK: - Quick Tic Log (manual from calendar quick-add)

    func logTicManually(category: TicCategory, typeName: String, outcome: TicOutcome) {
        let intent = TicLogIntent(category: category, typeName: typeName, outcome: outcome, count: 1)
        let entry = dataService.quickLog(intent: intent)
        lastLoggedEntry = entry

        // Add a confirmation chat message
        let confirmMsg = ChatMessage(
            role: .assistant,
            content: "Logged a \(typeName) tic! \(outcome.emoji) \(outcome.encouragement)"
        )
        messages.append(confirmMsg)
        saveHistory()
    }

    // MARK: - Persistence

    private func saveHistory() {
        // Keep last 100 messages
        let recent = Array(messages.suffix(100))
        if let data = try? JSONEncoder().encode(recent) {
            UserDefaults.standard.set(data, forKey: "ticbuddy_chat_history")
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "ticbuddy_chat_history"),
           let history = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = history
        }
    }

    func clearHistory() {
        messages = []
        UserDefaults.standard.removeObject(forKey: "ticbuddy_chat_history")
        addWelcomeMessage()
    }
}
