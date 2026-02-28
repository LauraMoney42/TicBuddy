// TicBuddy — CompetingResponses.swift
// CBIT-based competing response library.
// Based on published CBIT protocol (Woods et al., 2008) and TAA guidelines.
//
// A competing response must:
// 1. Be physically incompatible with the tic (can't do both at once)
// 2. Be subtle enough to use in public
// 3. Be held for ~1 minute or until urge passes
// 4. Be easy enough for a child to learn and remember

import Foundation

struct CompetingResponse: Identifiable {
    let id: String
    let forTicType: String        // matches TicMotorType/TicVocalType rawValue
    let title: String
    let instruction: String
    let kidFriendlyTip: String
    let holdDuration: Int          // seconds to hold
    let emoji: String

    // Whether this response works in public without drawing attention
    var isDiscreet: Bool { true }
}

struct CompetingResponseLibrary {

    // MARK: - Motor Tic Responses

    static let motorResponses: [CompetingResponse] = [

        CompetingResponse(
            id: "cr_eyeblink",
            forTicType: TicMotorType.eyeBlink.rawValue,
            title: "Slow Blink",
            instruction: "When you feel the urge to blink rapidly, slowly and gently close your eyes halfway (like you're sleepy) and hold for 5 seconds, then open slowly.",
            kidFriendlyTip: "Pretend you're a sleepy lion. Slow blinks only! 🦁",
            holdDuration: 30,
            emoji: "👁"
        ),

        CompetingResponse(
            id: "cr_headjerk",
            forTicType: TicMotorType.headJerk.rawValue,
            title: "Neck Press",
            instruction: "When you feel the urge to jerk your head, gently press the back of your head backward against an imaginary wall. Create a tiny bit of tension in your neck muscles. Hold gently.",
            kidFriendlyTip: "Be a turtle — pull your head in slowly! 🐢",
            holdDuration: 60,
            emoji: "🔄"
        ),

        CompetingResponse(
            id: "cr_shouldershrug",
            forTicType: TicMotorType.shoulderShrug.rawValue,
            title: "Shoulder Press Down",
            instruction: "When you feel the urge to shrug, push your shoulders DOWN instead — as if pressing them toward the floor. Hold gently for 1 minute.",
            kidFriendlyTip: "Pretend something heavy is on your shoulders, pushing them down. 📦",
            holdDuration: 60,
            emoji: "🤷"
        ),

        CompetingResponse(
            id: "cr_facialgrimace",
            forTicType: TicMotorType.facialGrimace.rawValue,
            title: "Face Relax",
            instruction: "When you feel the urge to grimace, instead relax ALL the muscles in your face completely. Mouth slightly open, forehead smooth, jaw loose. Hold this relaxed position.",
            kidFriendlyTip: "Make your face like a sleeping puppy — totally relaxed! 🐶",
            holdDuration: 45,
            emoji: "😬"
        ),

        CompetingResponse(
            id: "cr_armjerk",
            forTicType: TicMotorType.armJerk.rawValue,
            title: "Arm Press",
            instruction: "When you feel the urge to jerk your arm, press your arm firmly against the side of your body (or against your leg if sitting). Hold the gentle tension.",
            kidFriendlyTip: "Pin your arm to your side like a penguin! 🐧",
            holdDuration: 60,
            emoji: "💪"
        ),

        CompetingResponse(
            id: "cr_legjerk",
            forTicType: TicMotorType.legJerk.rawValue,
            title: "Foot Press",
            instruction: "When you feel the urge in your leg, press your foot firmly into the floor. Feel the floor pushing back. Hold the steady pressure.",
            kidFriendlyTip: "Press your foot into the ground like you're squishing something! 🦶",
            holdDuration: 60,
            emoji: "🦵"
        ),

        CompetingResponse(
            id: "cr_touching",
            forTicType: TicMotorType.touching.rawValue,
            title: "Fist Close",
            instruction: "When you feel the urge to touch, gently close your hand into a soft fist and squeeze slightly. Hold the squeeze. This keeps the hand occupied.",
            kidFriendlyTip: "Make a gentle fist like you're holding a butterfly — not too tight! 🦋",
            holdDuration: 60,
            emoji: "✋"
        ),

        CompetingResponse(
            id: "cr_jumping",
            forTicType: TicMotorType.jumping.rawValue,
            title: "Stand Still + Press Down",
            instruction: "When you feel the urge to jump, plant your feet firmly on the ground and press down through your heels. Bend knees slightly. Hold steady.",
            kidFriendlyTip: "Be a tree! Roots going into the ground. 🌳",
            holdDuration: 60,
            emoji: "⬆️"
        ),
    ]

    // MARK: - Vocal Tic Responses

    static let vocalResponses: [CompetingResponse] = [

        CompetingResponse(
            id: "cr_throatclear",
            forTicType: TicVocalType.throatClearing.rawValue,
            title: "Slow Nose Breath",
            instruction: "When you feel the urge to clear your throat, instead breathe in slowly through your nose (mouth closed) for 4 counts. Hold 2 counts. Out through nose for 4 counts. The urge will often pass.",
            kidFriendlyTip: "Breathe like you're smelling something AMAZING! 🌸",
            holdDuration: 30,
            emoji: "🗣"
        ),

        CompetingResponse(
            id: "cr_sniffing",
            forTicType: TicVocalType.sniffing.rawValue,
            title: "Mouth Breathe",
            instruction: "When you feel the urge to sniff, close your mouth, relax your nose, and breathe slowly through your mouth instead. The urge to sniff often disappears.",
            kidFriendlyTip: "Breathe like a fish for a few seconds! 🐠",
            holdDuration: 20,
            emoji: "👃"
        ),

        CompetingResponse(
            id: "cr_grunting",
            forTicType: TicVocalType.grunting.rawValue,
            title: "Gentle Hum",
            instruction: "When you feel the urge to grunt, instead press your lips together and breathe smoothly through your nose. Keep your voice box still and relaxed.",
            kidFriendlyTip: "Be a quiet ninja! Lips together, breathe through your nose. 🥷",
            holdDuration: 45,
            emoji: "😤"
        ),

        CompetingResponse(
            id: "cr_coughing",
            forTicType: TicVocalType.coughing.rawValue,
            title: "Swallow + Breathe",
            instruction: "When you feel the urge to cough, swallow once, then breathe in slowly through your nose. The swallow interrupts the cough urge.",
            kidFriendlyTip: "Swallow like you're drinking water, then breathe. 💧",
            holdDuration: 20,
            emoji: "🤧"
        ),

        CompetingResponse(
            id: "cr_wordphrase",
            forTicType: TicVocalType.wordOrPhrase.rawValue,
            title: "Lip Press + Breathe",
            instruction: "When you feel the urge to say the word or phrase, gently press your lips together and breathe slowly in through your nose. Keeping lips together makes it physically harder to vocalize.",
            kidFriendlyTip: "Zipper your lips! Press them together gently. 🤐",
            holdDuration: 60,
            emoji: "💬"
        ),

        CompetingResponse(
            id: "cr_humming",
            forTicType: TicVocalType.humming.rawValue,
            title: "Silent Exhale",
            instruction: "When you feel the urge to hum, breathe out silently through slightly open lips — no voice, just air. This satisfies the need to exhale without the sound.",
            kidFriendlyTip: "Breathe out like you're blowing on hot soup — no sound! 🍜",
            holdDuration: 20,
            emoji: "🎵"
        ),
    ]

    // MARK: - Lookup

    static func response(for ticTypeName: String) -> CompetingResponse? {
        let all = motorResponses + vocalResponses
        return all.first { $0.forTicType.lowercased() == ticTypeName.lowercased() }
    }

    static func responses(for ticNames: [String]) -> [CompetingResponse] {
        ticNames.compactMap { response(for: $0) }
    }

    /// Returns a kid-friendly explanation of competing responses for the chat bot
    static func chatDescription(for ticName: String) -> String {
        guard let cr = response(for: ticName) else {
            return "When you feel the urge to tic, try tensing the muscles in the opposite direction gently for about 1 minute. Take slow deep breaths through your nose. The urge usually passes! 💪"
        }
        return "Here's your superpower move for \(ticName):\n\n**\(cr.title)** \(cr.emoji)\n\n\(cr.instruction)\n\n💡 Tip: \(cr.kidFriendlyTip)\n\nTry holding it for about \(cr.holdDuration) seconds. You've got this! 🌟"
    }
}
