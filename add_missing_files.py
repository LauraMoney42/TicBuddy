#!/usr/bin/env python3
"""
Script to add 24 missing Swift files to TicBuddy's project.pbxproj.
"""

import re
import secrets

PROJECT_PATH = "/Users/macair/Documents/GIT/TicBuddy/TicBuddy.xcodeproj/project.pbxproj"

# ── UUIDs for existing groups ──────────────────────────────────────────────────
GROUP_MODELS    = "E4B9474851FDD503B9D7C66B"
GROUP_SERVICES  = "FFFA72600546CA9E824786F4"
GROUP_VIEWS     = "0EEB5F307248FD007DA517D1"
GROUP_HOME      = "7C5E3B670FC65924377AC154"
GROUP_ONBOARDING = "E41D1230E4AF537D5FBC8125"
GROUP_SETTINGS  = "C1E9DF338FF4362F3946CA93"

# ── New groups to create ──────────────────────────────────────────────────────
GROUP_CHILDMODE = "AA11BB22CC33DD44EE55FF66"   # Views/ChildMode
GROUP_EVENING   = "BB22CC33DD44EE55FF6600AA"   # Views/Evening

def new_uuid():
    """Generate a 24-char uppercase hex UUID matching Xcode style."""
    return secrets.token_hex(12).upper()

# ── File list: (filename, group_id) ───────────────────────────────────────────
FILES = [
    # Services
    ("CBITSessionStore.swift",      GROUP_SERVICES),
    ("COPPAComplianceService.swift", GROUP_SERVICES),
    ("COPPAConsentService.swift",   GROUP_SERVICES),
    ("ChatUsageLimiter.swift",      GROUP_SERVICES),
    ("DailyInstructionEngine.swift", GROUP_SERVICES),
    ("EveningCheckInService.swift", GROUP_SERVICES),
    ("FamilyPINService.swift",      GROUP_SERVICES),
    ("ZiggyContentFilter.swift",    GROUP_SERVICES),
    ("ZiggyTTSService.swift",       GROUP_SERVICES),
    ("ZiggyVoiceProfileService.swift", GROUP_SERVICES),
    # Models
    ("FamilyUnit.swift",            GROUP_MODELS),
    ("SessionMemory.swift",         GROUP_MODELS),
    # Views/Home
    ("CaregiverHomeView.swift",     GROUP_HOME),
    # Views/Onboarding
    ("COPPAConsentSheet.swift",     GROUP_ONBOARDING),
    ("DeviceConfigView.swift",      GROUP_ONBOARDING),
    ("FamilyOnboardingView.swift",  GROUP_ONBOARDING),
    # Views/Settings
    ("FamilyManagementView.swift",  GROUP_SETTINGS),
    # Views (top-level)
    ("FamilyModeRouter.swift",      GROUP_VIEWS),
    # Views/ChildMode (new group)
    ("ChildModeAdolescentView.swift", GROUP_CHILDMODE),
    ("ChildModeOlderView.swift",    GROUP_CHILDMODE),
    ("ChildModeYoungView.swift",    GROUP_CHILDMODE),
    ("RewardMilestoneSheet.swift",  GROUP_CHILDMODE),
    # Views/Evening (new group)
    ("EveningCheckInSheet.swift",   GROUP_EVENING),
    ("NightlyRitualSheet.swift",    GROUP_EVENING),
]

def main():
    with open(PROJECT_PATH, "r") as f:
        content = f.read()

    # ── Assign UUIDs ─────────────────────────────────────────────────────────
    file_refs  = {}   # filename -> fileRef UUID
    build_files = {}  # filename -> buildFile UUID
    for filename, _ in FILES:
        file_refs[filename]   = new_uuid()
        build_files[filename] = new_uuid()

    # ── 1. PBXFileReference entries ──────────────────────────────────────────
    new_file_refs = []
    for filename, _ in FILES:
        fref = file_refs[filename]
        line = f'\t\t{fref} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};'
        new_file_refs.append(line)

    insert_fref = "\n".join(new_file_refs) + "\n"
    content = content.replace(
        "/* End PBXFileReference section */",
        insert_fref + "/* End PBXFileReference section */"
    )

    # ── 2. PBXBuildFile entries ───────────────────────────────────────────────
    new_build_files = []
    for filename, _ in FILES:
        bf  = build_files[filename]
        ref = file_refs[filename]
        line = f'\t\t{bf} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {filename} */; }};'
        new_build_files.append(line)

    insert_bf = "\n".join(new_build_files) + "\n"
    content = content.replace(
        "/* End PBXBuildFile section */",
        insert_bf + "/* End PBXBuildFile section */"
    )

    # ── 3. Add new PBXGroup entries for ChildMode and Evening ─────────────────
    childmode_files = [f for f, g in FILES if g == GROUP_CHILDMODE]
    evening_files   = [f for f, g in FILES if g == GROUP_EVENING]

    def group_children_block(filenames):
        lines = []
        for fn in filenames:
            lines.append(f"\t\t\t\t{file_refs[fn]} /* {fn} */,")
        return "\n".join(lines)

    childmode_group = f"""
\t\t{GROUP_CHILDMODE} /* ChildMode */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children_block(childmode_files)}
\t\t\t);
\t\t\tpath = ChildMode;
\t\t\tsourceTree = "<group>";
\t\t}};"""

    evening_group = f"""
\t\t{GROUP_EVENING} /* Evening */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children_block(evening_files)}
\t\t\t);
\t\t\tpath = Evening;
\t\t\tsourceTree = "<group>";
\t\t}};"""

    content = content.replace(
        "/* End PBXGroup section */",
        childmode_group + "\n" + evening_group + "\n/* End PBXGroup section */"
    )

    # ── 4. Add ChildMode and Evening as children of the Views group ───────────
    # Insert after the last existing child in the Views group children list.
    # We locate the Views group block and append before the closing );
    # The Views group children currently end with:
    #     C1E9DF338FF4362F3946CA93 /* Settings */,
    # followed by );
    content = content.replace(
        "\t\t\t\tC1E9DF338FF4362F3946CA93 /* Settings */,\n\t\t\t);",
        f"\t\t\t\tC1E9DF338FF4362F3946CA93 /* Settings */,\n"
        f"\t\t\t\t{GROUP_CHILDMODE} /* ChildMode */,\n"
        f"\t\t\t\t{GROUP_EVENING} /* Evening */,\n"
        f"\t\t\t);"
    )

    # ── 5. Add files to their existing groups ─────────────────────────────────
    # Helper: insert file refs at end of a group's children list
    def insert_into_group(content, group_id, group_name, filenames):
        """Find the group block and append fileRef lines before its closing );"""
        # Build lines to insert
        new_lines = ""
        for fn in filenames:
            new_lines += f"\t\t\t\t{file_refs[fn]} /* {fn} */,\n"

        # Pattern: locate this specific group's children closing );
        # We use a regex that finds the group block by its UUID and replaces the last );
        # Strategy: find the group header, then find the FIRST ); after it
        group_header = f"{group_id} /* {group_name} */"

        idx = content.find(group_header)
        if idx == -1:
            print(f"  WARNING: Could not find group {group_name} ({group_id})")
            return content

        # Find the children = ( ... ); block after idx
        children_start = content.find("children = (", idx)
        if children_start == -1:
            print(f"  WARNING: No children block in group {group_name}")
            return content

        # Find the matching );
        paren_close = content.find(");", children_start)
        if paren_close == -1:
            print(f"  WARNING: No closing ); for group {group_name}")
            return content

        # Insert new lines before );
        content = content[:paren_close] + new_lines + content[paren_close:]
        return content

    # Services group
    services_files = [f for f, g in FILES if g == GROUP_SERVICES]
    content = insert_into_group(content, GROUP_SERVICES, "Services", services_files)

    # Models group
    models_files = [f for f, g in FILES if g == GROUP_MODELS]
    content = insert_into_group(content, GROUP_MODELS, "Models", models_files)

    # Home group
    home_files = [f for f, g in FILES if g == GROUP_HOME]
    content = insert_into_group(content, GROUP_HOME, "Home", home_files)

    # Onboarding group
    onboarding_files = [f for f, g in FILES if g == GROUP_ONBOARDING]
    content = insert_into_group(content, GROUP_ONBOARDING, "Onboarding", onboarding_files)

    # Settings group
    settings_files = [f for f, g in FILES if g == GROUP_SETTINGS]
    content = insert_into_group(content, GROUP_SETTINGS, "Settings", settings_files)

    # Views group (top-level files like FamilyModeRouter.swift)
    # The Views group has only subgroup references as children currently,
    # but we can still append a file ref the same way.
    views_direct = [f for f, g in FILES if g == GROUP_VIEWS]
    content = insert_into_group(content, GROUP_VIEWS, "Views", views_direct)

    # ── 6. Add build files to PBXSourcesBuildPhase ────────────────────────────
    new_sources = []
    for filename, _ in FILES:
        bf = build_files[filename]
        new_sources.append(f"\t\t\t\t{bf} /* {filename} in Sources */,")

    insert_sources = "\n".join(new_sources) + "\n"
    content = content.replace(
        "\t\t\t\t3C34DE5C305BAD18189CD26D /* WelcomeKindnessView.swift in Sources */,",
        f"\t\t\t\t3C34DE5C305BAD18189CD26D /* WelcomeKindnessView.swift in Sources */,\n{insert_sources}"
    )

    # ── 7. Write modified file ────────────────────────────────────────────────
    with open(PROJECT_PATH, "w") as f:
        f.write(content)

    print("Done! project.pbxproj has been updated.")

    # ── 8. Verify required section markers are present ────────────────────────
    required_markers = [
        "/* Begin PBXBuildFile section */",
        "/* End PBXBuildFile section */",
        "/* Begin PBXFileReference section */",
        "/* End PBXFileReference section */",
        "/* Begin PBXGroup section */",
        "/* End PBXGroup section */",
        "/* Begin PBXNativeTarget section */",
        "/* End PBXNativeTarget section */",
        "/* Begin PBXProject section */",
        "/* End PBXProject section */",
        "/* Begin PBXSourcesBuildPhase section */",
        "/* End PBXSourcesBuildPhase section */",
    ]

    print("\nVerifying section markers...")
    all_ok = True
    for marker in required_markers:
        if marker in content:
            print(f"  OK  {marker}")
        else:
            print(f"  MISSING  {marker}")
            all_ok = False

    if all_ok:
        print("\nAll section markers present. File looks valid.")
    else:
        print("\nWARNING: Some markers missing — review the file!")

    # Print UUID summary
    print("\nUUID assignments:")
    print(f"  ChildMode group: {GROUP_CHILDMODE}")
    print(f"  Evening group:   {GROUP_EVENING}")
    for filename, group in FILES:
        print(f"  {filename}: fileRef={file_refs[filename]}  buildFile={build_files[filename]}")

if __name__ == "__main__":
    main()
