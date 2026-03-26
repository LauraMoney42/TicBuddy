// TicBuddy — LessonSlide.swift
// Data models for the slide-based CBIT lesson engine (tb-mvp2-059).
// Lessons are pre-written, clinician-reviewed content — Ziggy TTS reads them
// aloud but does NOT generate the content, eliminating hallucination risk on
// core CBIT education. Post-lesson, Ziggy chat activates for Q&A + practice.

import Foundation

// MARK: - LessonSlide

/// A single slide in a CBIT lesson. Matches the JSON schema:
/// { "id": Int, "title": String, "body": String, "audioHint": String? }
struct LessonSlide: Codable, Identifiable {
    let id: Int
    /// Short heading displayed at the top of the slide card.
    let title: String
    /// Main educational body text read aloud by Ziggy TTS.
    let body: String
    /// Optional pacing hint passed to TTS (e.g. "pause after first sentence").
    /// Not displayed to the user — used only to guide future TTS tuning.
    let audioHint: String?
    /// tb-mvp2-071: Hero emoji displayed prominently on the slide card.
    /// Nil-safe — older slide data without this field renders without a hero.
    let emoji: String?
    /// tb-mvp2-102: Optional Ziggy prompt — if set, a secondary "Ask Ziggy →" CTA
    /// appears on this slide. The text is pre-loaded as the user's opening message
    /// so Ziggy can give a targeted, contextual response immediately.
    let ziggyPrompt: String?

    init(id: Int, title: String, body: String, audioHint: String? = nil, emoji: String? = nil, ziggyPrompt: String? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.audioHint = audioHint
        self.emoji = emoji
        self.ziggyPrompt = ziggyPrompt
    }

    /// tb-mvp2-087: Full spoken text for TTS — title as audio heading + cleaned body.
    /// Strips "## " markdown markers so they aren't read aloud.
    /// ALL call sites (speakLesson, prefetchLessonSlide, slide-0 pre-warm) must use
    /// this property so the cache key is identical everywhere.
    var spokenText: String {
        let cleanBody = body
            .components(separatedBy: "\n")
            .map { $0.hasPrefix("## ") ? String($0.dropFirst(3)) : $0 }
            .joined(separator: "\n")
        return "\(title). \(cleanBody)"
    }
}

// MARK: - CBITLesson

/// A full lesson for one CBIT session — a title + ordered array of slides.
struct CBITLesson: Codable {
    let session: Int
    let title: String
    let subtitle: String
    let slides: [LessonSlide]
}
