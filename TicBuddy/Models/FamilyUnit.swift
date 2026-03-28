// TicBuddy — FamilyUnit.swift
// Top-level account model for the Family Unit architecture.
// One family unit contains multiple caregiver and child profiles,
// each with their own CBIT data, PIN, and privacy boundaries.

import Foundation

// MARK: - CBIT Session Stage
// Full 8-session clinical protocol per CBIT manual.
// Replaces the week-based CBITPhase for family platform use;
// CBITPhase is preserved in UserProfile for legacy single-user compatibility.

enum CBITSessionStage: Int, Codable, CaseIterable {
    case session1 = 1   // Foundation — psychoeducation, tic inventory, awareness training
    case session2 = 2   // First Competing Response introduced
    case session3 = 3   // Troubleshoot, deepen + relaxation intro
    case session4 = 4   // Consolidation + second tic CR
    case session5 = 5   // Pre-biweekly transition
    case session6 = 6   // Biweekly maintenance
    case session7 = 7   // Monthly maintenance
    case session8 = 8   // Final session + relapse prevention plan

    var title: String {
        switch self {
        case .session1: return "Lesson 1: CBIT Foundations"   // tb-mvp2-142
        case .session2: return "Session 2: Your First Tool"
        case .session3: return "Session 3: Deepen & Troubleshoot"
        case .session4: return "Session 4: Consolidate"
        case .session5: return "Session 5: Building Independence"
        case .session6: return "Session 6: Biweekly Check-In"
        case .session7: return "Session 7: Monthly Maintenance"
        case .session8: return "Session 8: You've Got This"
        }
    }

    var shortLabel: String { "Session \(rawValue) of 8" }

    /// Sessions 1–5 are weekly; 6–8 are biweekly then monthly
    var isMaintenancePhase: Bool { rawValue >= 6 }

    var spacingDescription: String {
        switch rawValue {
        case 1...5: return "Weekly"
        case 6...7: return "Biweekly"
        default:    return "Monthly"
        }
    }
}

// MARK: - Practice Status
// Daily practice quality — used in the shared practice calendar.

enum PracticeStatus: String, Codable {
    case fullPractice = "green"   // Complete practice session
    case partial      = "yellow"  // Partial practice
    case hardDay      = "blank"   // Hard day — no practice (no shame, just record)
}

// MARK: - Shared Family Data
// State synced in real time across all devices in the family unit.
// Only this data crosses profile boundaries — all other data is private.

// MARK: - Evening Check-In Summary (tb-mvp2-018)
//
// The ONLY child data that crosses to the parent view — mood emoji + energy + practice.
// Free text, journal entries, and trigger notes NEVER appear here.
// Privacy boundary is enforced in TicDataService.submitEveningCheckIn().

struct EveningCheckInSummary: Codable {
    /// Child-selected mood: "😊" / "😐" / "😣"
    var moodEmoji: String
    /// Energy level 1–3: 1 = low, 2 = medium, 3 = high
    var energyLevel: Int
    /// Did the child do their competing response practice today?
    var practiceDoneToday: Bool
    /// When the check-in was submitted
    var timestamp: Date = Date()
}

struct SharedFamilyData: Codable {
    // Reward system
    var rewardPoints: Int = 0
    var rewardTierIndex: Int = 0         // Index into caregiver's configured reward tiers

    // Practice calendar — ISO8601 date string → PracticeStatus
    var practiceCalendar: [String: PracticeStatus] = [:]

    // CBIT session stage — caregiver advances this; child mode auto-updates
    var currentSessionStage: CBITSessionStage = .session1

    // Whether family is working with a CBIT therapist
    var hasTherapist: Bool = false

    // tb-mvp2-018: Evening check-ins — ISO8601 date key → summary (no private journal text)
    var eveningCheckIns: [String: EveningCheckInSummary] = [:]

    // tb-mvp2-024: PIN gate for returning to caregiver mode (default OFF — one tap to exit)
    var requirePINForCaregiverSwitch: Bool = false

    // Timestamp for future sync conflict resolution (V2 CloudKit)
    var lastModified: Date = Date()
}

// MARK: - Tic Hierarchy Entry
// One tic in the child's ordered treatment hierarchy.
// CBIT works through this list from most to least distressing.

struct TicHierarchyEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var ticName: String                  // canonical type name e.g. "Eye Blink"
    /// tb-mvp2-082: Optional user-given nickname e.g. "The Flutter", "My Blurt".
    /// When set, shown as the primary label throughout the app.
    var nickname: String = ""
    var category: TicCategory            // .motor or .vocal
    var distressRating: Int              // 1–10; drives hierarchy ordering
    var frequencyPerDay: Int             // estimated daily occurrences
    var hasPremonitoryUrge: Bool = false
    var urgeDescription: String = ""     // child's own words for the premonitory urge
    var competingResponse: String = ""   // the assigned CR for this tic
    var sessionIntroduced: CBITSessionStage = .session2
    var isCurrentlyActive: Bool = true   // whether this tic is the current target
    var hierarchyOrder: Int              // 0 = highest priority / most distressing

    // Outcome tracking across sessions
    var baselineDistress: Int = 0        // distress rating when CR was introduced
    var currentDistress: Int = 0         // most recent rating (updated each session)

    /// Display name: nickname if set, otherwise the canonical ticName.
    var displayName: String { nickname.isEmpty ? ticName : nickname }
}

// MARK: - Age Group

/// Drives child UI sub-mode, PIN requirements, and privacy boundaries.
/// Matches the design spec age buckets exactly.
enum AgeGroup: String, Codable, CaseIterable {
    case veryYoung  = "4-6"
    case young      = "7-9"
    case olderChild = "10-12"
    case youngTeen  = "13-15"
    case teen       = "16-17"
    case adult      = "18+"

    var displayName: String { rawValue + " years" }

    /// Minimum age in the bracket (used for onboarding age picker)
    var minimumAge: Int {
        switch self {
        case .veryYoung:  return 4
        case .young:      return 7
        case .olderChild: return 10
        case .youngTeen:  return 13
        case .teen:       return 16
        case .adult:      return 18
        }
    }

    /// Whether child profile requires a PIN to open child mode
    var requiresChildPIN: Bool {
        // Ages 4–6 open — no authentication needed to enter child mode
        self != .veryYoung
    }

    /// Whether child's PIN is kept private from caregivers.
    /// Ages 10+ can set a PIN their caregiver does not know.
    var childPINIsPrivate: Bool {
        switch self {
        case .veryYoung, .young: return false
        case .olderChild, .youngTeen, .teen, .adult: return true
        }
    }

    /// Maps to the UI sub-mode name shown in the child view
    var subModeName: String {
        switch self {
        case .veryYoung, .young: return "Young Child"
        case .olderChild:        return "Older Child"
        case .youngTeen, .teen:  return "Adolescent"
        case .adult:             return "Adult"
        }
    }

    /// Whether this age group shows the private journal feature
    var hasPrivateJournal: Bool {
        switch self {
        case .youngTeen, .teen: return true
        default: return false
        }
    }

    /// Whether parent can see detailed log entries (vs summary only)
    var parentSeesDetailedLogs: Bool {
        switch self {
        case .veryYoung, .young, .olderChild: return true
        case .youngTeen, .teen, .adult: return false  // adolescent/adult privacy — summary only
        }
    }
}

// MARK: - Account Type

/// Distinguishes users who have tics themselves from those managing a child's program.
/// Set during onboarding (step 0 role selection) and drives routing + Ziggy framing.
enum AccountType: String, Codable {
    /// Parent, guardian, grandparent, or therapist using TicBuddy on behalf of a child.
    case caregiver  = "caregiver"
    /// Adult or teen (13+) using TicBuddy for their own tic management program.
    case selfUser   = "self_user"
}

// MARK: - Caregiver Profile

enum CaregiverRelationship: String, Codable, CaseIterable {
    case parent      = "Parent"
    case grandparent = "Grandparent"
    case guardian    = "Guardian"
    case therapist   = "Therapist"
}

struct CaregiverProfile: Codable, Identifiable {
    var id: UUID = UUID()
    var displayName: String = ""
    var relationship: CaregiverRelationship = .parent
    /// True when a PIN has been saved to Keychain for this profile.
    /// PIN value itself never stored in this struct — Keychain only.
    var hasPIN: Bool = false
    var createdAt: Date = Date()
}

// MARK: - Device Configuration

/// How the family uses devices with TicBuddy
enum DeviceConfig: String, Codable, CaseIterable {
    /// Child has their own device linked to this family unit via QR/code
    case separateDevices = "Separate Devices"
    /// All profiles on one device with a profile switcher on the home screen
    case singleDevice    = "Single Device"
    /// Caregiver manages everything; child-facing features launched from caregiver view
    case caregiverOnly   = "Caregiver Only"

    var description: String {
        switch self {
        case .separateDevices:
            return "On their own device — I'll set up their profile separately"
        case .singleDevice:
            return "On my device — we'll switch between profiles"
        case .caregiverOnly:
            return "Mostly me for now — they're too young to use it independently"
        }
    }
}

// MARK: - Child Profile

struct ChildProfile: Codable, Identifiable {
    var id: UUID = UUID()
    /// Nickname or first name only — never a full legal name
    var nickname: String = ""
    var ageGroup: AgeGroup = .olderChild
    var deviceConfig: DeviceConfig = .singleDevice
    /// True when a PIN has been saved to Keychain for this profile
    var hasPIN: Bool = false
    var hasCompletedOnboarding: Bool = false
    /// The child's CBIT program state — kept inside their profile for multi-child support
    var userProfile: UserProfile = UserProfile()
    var createdAt: Date = Date()

    // MARK: - CBIT Session Tracking (Family Platform)
    // sessionStage drives caregiver daily instructions and child mode content.
    // Starts at session1; advanced by caregiver or therapist.
    var sessionStage: CBITSessionStage = .session1

    // Ordered list of tics from most to least distressing.
    // CBIT works through this list one tic at a time.
    var ticHierarchy: [TicHierarchyEntry] = []

    /// Max Ziggy messages per day for this child. 0 = unlimited (caregiver/therapist use).
    /// Default comes from ChatUsageLimiter.defaultDailyLimit (20).
    /// Caregiver adjusts this in Settings > Family > [child] > Usage Limits.
    var dailyMessageLimit: Int = ChatUsageLimiter.defaultDailyLimit

    // MARK: Computed

    /// User-facing display name for this child (falls back to "Child" if not set)
    var displayName: String {
        nickname.isEmpty ? "Child" : nickname
    }

    /// Whether this child's profile can be opened without a PIN
    var isOpenAccess: Bool { !ageGroup.requiresChildPIN || !hasPIN }

    /// The tic currently being targeted in treatment (highest priority active tic)
    var currentTargetTic: TicHierarchyEntry? {
        ticHierarchy
            .filter { $0.isCurrentlyActive }
            .sorted { $0.hierarchyOrder < $1.hierarchyOrder }
            .first
    }
}

// MARK: - Family Unit

/// The top-level account entity. One per family subscription.
/// Shared state (reward totals, session stage, practice calendar) lives in sharedData
/// and syncs across all devices. Private state (journal, detailed logs) lives in
/// individual child profiles and never crosses to other profiles.
struct FamilyUnit: Codable {
    var id: UUID = UUID()
    var caregivers: [CaregiverProfile] = []
    var children: [ChildProfile] = []
    /// UUID of the child profile currently active (nil = app is in caregiver mode)
    var activeChildID: UUID? = nil
    /// Whether the initial family setup flow has been completed
    var hasCompletedSetup: Bool = false
    /// Whether the primary user is a caregiver for a child or managing their own tics.
    /// Set in onboarding step 0; drives routing and Ziggy session framing.
    var accountType: AccountType = .caregiver
    var createdAt: Date = Date()

    // Shared data synced across all devices in real time.
    // Reward points, practice calendar, and session stage live here.
    var sharedData: SharedFamilyData = SharedFamilyData()

    // MARK: Convenience

    var primaryCaregiver: CaregiverProfile? { caregivers.first }

    var activeChild: ChildProfile? {
        guard let id = activeChildID else { return nil }
        return children.first { $0.id == id }
    }

    /// True when app is showing a child's profile (not caregiver view)
    var isInChildMode: Bool { activeChildID != nil }

    /// Returns the index of a child by ID (for in-place mutation)
    func childIndex(id: UUID) -> Int? {
        children.firstIndex { $0.id == id }
    }
}
