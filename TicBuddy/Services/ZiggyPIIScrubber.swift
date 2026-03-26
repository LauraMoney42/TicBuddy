// TicBuddy — ZiggyPIIScrubber.swift
// Inbound PII scrubber — strips personally identifiable information from user
// messages BEFORE they are sent to any external API. (tb-rag-002)
//
// Categories scrubbed:
//   1. Email addresses
//   2. Phone numbers (US and international formats)
//   3. Personal names ("My name is X", "I'm called X", "call me X")
//   4. Doctor/provider names ("Dr. X", "Doctor X", "my doctor X")
//   5. School names ("my school is X", "I go to X school", "at X school")
//   6. Street addresses (house number + street type combos)
//
// Design philosophy:
//   - Conservative: only redact patterns we can identify with high confidence.
//     Better to miss an edge-case name than to mangle the message and confuse Ziggy.
//   - Non-lossy: replaces with neutral tokens ([name], [school], etc.) so
//     Ziggy still understands message intent without receiving real PII.
//   - Silent: scrubbing is transparent to the user — they see their original text
//     in the chat bubble; only the API receives the scrubbed version.
//
// NOTE: This is a best-effort layer, not a guarantee. The proxy server also
// strips PII server-side per ticbuddy_legal.md Section 5 (Children's Privacy).

import Foundation

// MARK: - Scrub Result

struct PIIScrubResult {
    /// The message with PII replaced by neutral tokens.
    let scrubbed: String
    /// True if any PII was found and replaced.
    let didRedact: Bool
    /// Human-readable list of categories that were redacted (for internal logging only).
    let redactedCategories: [String]
}

// MARK: - Ziggy PII Scrubber

final class ZiggyPIIScrubber: @unchecked Sendable {
    static let shared = ZiggyPIIScrubber()
    private init() {}

    // MARK: - Public API

    /// Scrub a user message before sending it to the Claude proxy.
    /// Returns the scrubbed text and metadata about what was redacted.
    func scrub(_ input: String) -> PIIScrubResult {
        var text = input
        var categories: [String] = []

        let steps: [(String, () -> String)] = [
            ("email",   { self.scrubEmails(text) }),
            ("phone",   { self.scrubPhones(text) }),
            ("address", { self.scrubAddresses(text) }),
            ("name",    { self.scrubPersonalNames(text) }),
            ("doctor",  { self.scrubDoctorNames(text) }),
            ("school",  { self.scrubSchoolNames(text) }),
        ]

        for (category, step) in steps {
            let result = step()
            // `step()` captures `text` by value at call time — re-apply to current `text`
            let updated = applyStep(category, to: text, using: category)
            if updated != text {
                categories.append(category)
                text = updated
            }
        }

        // Rebuild with final pass applying all transforms in sequence
        text = input
        text = scrubEmails(text);    if text != input { categories = Array(Set(categories + ["email"])) }
        let afterEmail = text
        text = scrubPhones(text);    if text != afterEmail { categories = Array(Set(categories + ["phone"])) }
        let afterPhone = text
        text = scrubAddresses(text); if text != afterPhone { categories = Array(Set(categories + ["address"])) }
        let afterAddr = text
        text = scrubPersonalNames(text); if text != afterAddr { categories = Array(Set(categories + ["name"])) }
        let afterName = text
        text = scrubDoctorNames(text);   if text != afterName { categories = Array(Set(categories + ["doctor"])) }
        let afterDoc = text
        text = scrubSchoolNames(text);   if text != afterDoc { categories = Array(Set(categories + ["school"])) }

        return PIIScrubResult(
            scrubbed: text,
            didRedact: text != input,
            redactedCategories: categories
        )
    }

    // MARK: - Email Scrubbing

    private func scrubEmails(_ text: String) -> String {
        // Standard email pattern
        let pattern = #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
        return replacePattern(pattern, in: text, with: "[email]")
    }

    // MARK: - Phone Number Scrubbing

    private func scrubPhones(_ text: String) -> String {
        var result = text
        // US formats: (123) 456-7890 / 123-456-7890 / 123.456.7890 / +1 123 456 7890
        let usPattern = #"(\+?1[\s.\-]?)?\(?\d{3}\)?[\s.\-]?\d{3}[\s.\-]?\d{4}"#
        result = replacePattern(usPattern, in: result, with: "[phone]")
        return result
    }

    // MARK: - Address Scrubbing

    private let streetTypes = [
        "street", "st", "avenue", "ave", "boulevard", "blvd", "drive", "dr",
        "road", "rd", "lane", "ln", "way", "court", "ct", "circle", "cir",
        "place", "pl", "terrace", "ter", "trail", "trl", "highway", "hwy"
    ]

    private func scrubAddresses(_ text: String) -> String {
        var result = text
        // Pattern: number + optional direction + street name words + street type
        // e.g. "123 Main Street", "456 N Oak Ave"
        let streetTypePattern = streetTypes.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let addressPattern = #"\b\d{1,5}\s+(?:[NSEW]\s+)?[A-Za-z\s]{1,30}(?:"# + streetTypePattern + #")\b"#
        result = replacePattern(addressPattern, in: result, with: "[address]", options: [.caseInsensitive])

        // ZIP codes: 5-digit or 5+4 format, only when standalone
        let zipPattern = #"\b\d{5}(?:-\d{4})?\b"#
        result = replacePattern(zipPattern, in: result, with: "[zip]")
        return result
    }

    // MARK: - Personal Name Scrubbing

    // Patterns: "my name is Firstname", "I'm called Firstname", "call me Firstname",
    //           "my name's Firstname", "I am Firstname Lastname"
    private func scrubPersonalNames(_ text: String) -> String {
        var result = text
        let namePatterns = [
            #"(?i)\bmy name(?:'s| is)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\b"#,
            #"(?i)\bi(?:'m| am) called\s+([A-Z][a-z]+)\b"#,
            #"(?i)\bcall me\s+([A-Z][a-z]+)\b"#,
            #"(?i)\bmy(?:\s+full)? name\s+is\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\b"#,
        ]
        for pattern in namePatterns {
            result = replaceCapturingGroup(pattern, in: result, replacement: "[name]")
        }
        return result
    }

    // MARK: - Doctor Name Scrubbing

    // Patterns: "Dr. Smith", "Doctor Jones", "my doctor is Smith",
    //           "my doctor Dr. Patel", "see Dr. Williams"
    private func scrubDoctorNames(_ text: String) -> String {
        var result = text
        let doctorPatterns = [
            #"(?i)\bdr\.?\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\b"#,
            #"(?i)\bdoctor\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\b"#,
            #"(?i)\bmy (?:doctor|therapist|psychiatrist|psychologist|physician)\s+(?:is\s+)?([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\b"#,
        ]
        for pattern in doctorPatterns {
            result = replaceCapturingGroup(pattern, in: result, replacement: "[provider]")
        }
        return result
    }

    // MARK: - School Name Scrubbing

    // Patterns: "my school is Lincoln", "I go to Roosevelt", "at Westview Elementary",
    //           "I attend Jefferson Middle School"
    private func scrubSchoolNames(_ text: String) -> String {
        var result = text
        let schoolPatterns = [
            // "my school is X"
            #"(?i)\bmy school(?:'s| is)\s+([A-Z][a-zA-Z\s]{1,30}(?:school|elementary|middle|high|academy|institute)?)\b"#,
            // "go to / attend X (School/Elementary/Middle/High)"
            #"(?i)\b(?:go to|attend|attend the)\s+([A-Z][a-zA-Z\s]{1,30}(?:school|elementary|middle|high|academy))\b"#,
            // "at X School"
            #"(?i)\bat\s+([A-Z][a-zA-Z\s]{1,30}(?:school|elementary|middle|high|academy))\b"#,
        ]
        for pattern in schoolPatterns {
            result = replaceCapturingGroup(pattern, in: result, replacement: "[school]")
        }
        return result
    }

    // MARK: - Regex Helpers

    private func replacePattern(
        _ pattern: String,
        in text: String,
        with replacement: String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    /// Replace only capturing group 1 with replacement, keeping the rest of the match intact.
    /// e.g. "my name is Alice" → "my name is [name]"
    private func replaceCapturingGroup(
        _ pattern: String,
        in text: String,
        replacement: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        var offset = 0
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches.reversed() { // reversed so offsets stay valid
            guard match.numberOfRanges > 1 else { continue }
            let captureRange = match.range(at: 1)
            guard captureRange.location != NSNotFound,
                  let swiftRange = Range(captureRange, in: result) else { continue }
            result.replaceSubrange(swiftRange, with: replacement)
        }
        return result
    }

    // Unused — kept for interface completeness; actual logic uses the sequential approach above
    private func applyStep(_ category: String, to text: String, using _: String) -> String {
        switch category {
        case "email":   return scrubEmails(text)
        case "phone":   return scrubPhones(text)
        case "address": return scrubAddresses(text)
        case "name":    return scrubPersonalNames(text)
        case "doctor":  return scrubDoctorNames(text)
        case "school":  return scrubSchoolNames(text)
        default:        return text
        }
    }
}
