# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Aumeno is a macOS SwiftUI application targeting macOS 15.6+ that fetches Slack messages and provides floating note windows for meetings. It supports multiple Slack workspaces, keyword filtering, and automatic meeting scheduling with notifications.

## Build System

This is an Xcode project. All builds and operations must be performed through Xcode or xcodebuild.

### Building the App

```bash
# Build for debugging
xcodebuild -project Aumeno.xcodeproj -scheme Aumeno -configuration Debug build

# Build for release
xcodebuild -project Aumeno.xcodeproj -scheme Aumeno -configuration Release build

# Clean build folder
xcodebuild -project Aumeno.xcodeproj -scheme Aumeno clean
```

### Running the App

The app can be run through Xcode (Cmd+R) or built and run via command line:

```bash
# Build and run
xcodebuild -project Aumeno.xcodeproj -scheme Aumeno -configuration Debug
open build/Debug/Aumeno.app
```

## Project Configuration

- **Bundle Identifier**: com.sandbox.Aumeno
- **Development Team**: H7825NYH4G
- **Deployment Target**: macOS 15.6
- **Swift Version**: 5.0
- **App Sandbox**: Enabled (network connections allowed)
- **Hardened Runtime**: Enabled

### Swift Compiler Settings

- `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`

## Code Architecture

Aumeno follows MVVM architecture with dual SQLite databases and a minimalist dark theme design system.

### Architecture Pattern: MVVM

- **Models**: Data structures (`Meeting`, `SlackConfiguration`)
- **Services**: Business logic (DatabaseManager, ConfigurationManager, SlackService, MeetingScheduler)
- **ViewModels**: State management (MeetingViewModel)
- **Views**: SwiftUI UI components
- **Utils**: Helper classes (FloatingWindowController)

### Application Entry Point

`AumenoApp.swift` - Main app with AppDelegate integration for notifications. Custom menu commands include Cmd+R for manual sync.

### Data Layer

**Two separate SQLite databases:**

1. **Meetings Database** (DatabaseManager.swift)
   - Stores `Meeting` records (both Slack-sourced and manually created)
   - Tracks deleted Slack messages to prevent re-import
   - Location: `~/Library/Application Support/Aumeno/aumeno.sqlite`

2. **Configurations Database** (ConfigurationManager.swift)
   - Stores `SlackConfiguration` records (multi-workspace support)
   - Each config has: name, token, channelID, keywords[], isEnabled
   - Location: `~/Library/Application Support/Aumeno/aumeno.sqlite` (same file, separate table)

**Models/Meeting.swift**
- Core meeting data model
- Links to SlackConfiguration via `slackConfigID` (optional, nil for manual meetings)
- Uses Slack timestamp (`ts`) as unique identifier for Slack-sourced meetings
- Manual meetings use UUID as ID

**Models/SlackConfiguration.swift**
- Represents a Slack workspace integration
- Keyword filtering: empty keywords = fetch all messages
- `matchesKeywords()` method for filtering messages

### Network Layer

**Services/SlackService.swift**
- Fetches from multiple Slack workspaces via ConfigurationManager
- `fetchMessagesFromAllConfigurations()` aggregates from all enabled configs
- Korean meeting format parser (extracts title, time, location, Notion links)
- Only fetches messages from last 7 days
- Keyword filtering applied at fetch time

### Business Logic Layer

**Services/MeetingScheduler.swift**
- Background scheduler checking every 60 seconds for upcoming meetings
- Sends advance notifications (5 minutes before)
- Auto-opens floating note window at meeting start time
- Prevents duplicate notifications via `notifiedMeetings` set

**ViewModels/MeetingViewModel.swift**
- Polls Slack every 10 seconds for new messages
- Filters out already-imported and deleted messages
- Coordinates between SlackService, DatabaseManager, and MeetingScheduler
- First-launch detection triggers onboarding

### UI Layer

**Views/MeetingListView.swift**
- Main window with dark theme (#1E1E1E background)
- Header with sync/settings/new meeting/keyword manager buttons
- **Filter chips UI**: Horizontal scrollable chips to filter by Slack workspace or "All"/"Manual"
- `filteredMeetings` computed property filters based on `selectedFilter` state
- Status bar with connection indicator and message count
- Opens floating note window on meeting tap
- Shows onboarding on first launch

**Views/OnboardingView.swift**
- 3-step onboarding wizard (welcome → Slack config → keywords)
- **Comprehensive Slack setup guide**: Step-by-step instructions for creating Slack Token (OAuth scopes: `channels:history`, `channels:read`) and finding Channel ID
- `HelpSection` component displays formatted bullet-point instructions
- "Open Slack API" button to launch api.slack.com/apps
- Uses `FlowLayout` for keyword chips
- Saves first SlackConfiguration to database

**Views/SlackConfigurationView.swift**
- Manage multiple Slack workspace integrations
- CRUD operations on configurations
- Dark theme UI with ghost-style buttons

**Views/MeetingEditorView.swift**
- Manual meeting creation/editing
- Date/time picker for scheduling
- Only used for manual meetings (not Slack-sourced)

**Views/KeywordManagerView.swift**
- Centralized keyword management across all configurations

**Views/NotePopupView.swift**
- Floating borderless window for meeting notes
- **Editable meeting info section**: Edit/Done toggle allows editing title, scheduled time, location, and link
- `editingInfoView` displays input fields; `displayInfoView` shows read-only info
- TextEditor with auto-save (1-second debounce) and save status indicator (Saving.../Saved)
- Updates `Meeting.note` and meeting metadata in database

**Utils/FloatingWindowController.swift**
- Custom NSPanel subclass
- `.borderless`, `.floating` level
- Movable by background dragging

**App/AppDelegate.swift**
- UNUserNotificationCenterDelegate
- Handles notification taps to open floating note window
- Sets `MeetingScheduler.onMeetingTime` closure

### Design System

**Dark Theme with Grayscale**
- Background: `Color(red: 0.12, green: 0.12, blue: 0.12)` (#1E1E1E)
- Primary text: `Color(white: 0.93)` (#EEEEEE)
- Secondary text: `Color(white: 0.67)` (#AAAAAA)
- Ghost buttons: transparent with gray borders
- NO bright colors except status indicators (green for active/ongoing, orange for upcoming)

### Key Features

1. **Multi-Workspace Support**: Multiple Slack configurations with independent keyword filters
2. **Keyword Filtering**: Per-workspace keyword lists (empty = fetch all)
3. **Korean Format Parsing**: Extracts meeting details from Korean Slack messages
4. **Auto-Scheduling**: MeetingScheduler auto-opens notes at meeting time
5. **Manual Meetings**: Create meetings manually without Slack
6. **Dual Database**: Separate tables for meetings and configurations
7. **Onboarding Flow**: First-launch wizard for Slack setup

### Threading & Concurrency

- Database operations: Dispatched to serial DispatchQueue for thread safety
- Network calls: Async/await with URLSession
- UI updates: @MainActor for SwiftUI
- Polling: Timer on main thread → async tasks
- MeetingScheduler: Separate 60-second timer

### File Organization

```
Aumeno/
├── App/
│   └── AppDelegate.swift              # Notification delegate
├── Models/
│   ├── Meeting.swift                  # Meeting data model
│   └── SlackConfiguration.swift       # Slack config model
├── Services/
│   ├── DatabaseManager.swift         # Meetings SQLite DB
│   ├── ConfigurationManager.swift    # Configs SQLite DB
│   ├── SlackService.swift            # Slack API + Korean parser
│   └── MeetingScheduler.swift        # Background scheduler
├── ViewModels/
│   └── MeetingViewModel.swift        # State + sync logic
├── Views/
│   ├── MeetingListView.swift         # Main window
│   ├── NotePopupView.swift           # Floating note editor
│   ├── OnboardingView.swift          # First-launch wizard
│   ├── SlackConfigurationView.swift  # Multi-workspace manager
│   ├── MeetingEditorView.swift       # Manual meeting creator
│   └── KeywordManagerView.swift      # Keyword management
├── Utils/
│   └── FloatingWindowController.swift # Custom floating window
└── AumenoApp.swift                    # App entry point
```

### Recent Changes (2025-01)

**UI/UX Improvements:**
- **Removed macOS Notes sync**: Previous AppleScript-based sync to macOS Notes app was unreliable and has been removed. Notes are now stored only in the local SQLite database.
- **Editable meeting info**: All meeting metadata (title, time, location, link) can now be edited directly in NotePopupView, not just in MeetingEditorView.
- **Slack workspace filtering**: Added horizontal filter chips in MeetingListView to filter meetings by Slack workspace, manual meetings, or show all.
- **Enhanced onboarding**: OnboardingView now includes comprehensive step-by-step guides for obtaining Slack Token and Channel ID, with HelpSection component and direct link to Slack API portal.

**Services/NotesAppService.swift** is currently unused but retained for potential future integration. The `syncToNotesApp()` method and AppleScript implementation are not called from any active UI.

### Important Implementation Details

**Slack Message Deduplication:**
- `DatabaseManager.meetingExists(id:)` checks if meeting already imported
- `DatabaseManager.isDeletedSlackMessage(timestamp:)` prevents re-import of deleted messages
- Deleted messages are tracked in a separate `deleted_slack_messages` table

**Meeting Scheduling Flow:**
1. SlackService parses Korean format to extract `scheduledTime`
2. Meeting saved to database with `notificationSent = false`
3. MeetingScheduler polls database every 60s for upcoming meetings
4. At meeting time: sends notification + calls `onMeetingTime` closure
5. AppDelegate opens floating window via closure

**Configuration Management:**
- Each Slack workspace = one `SlackConfiguration` row
- Configurations can be disabled without deletion
- Keywords are JSON-encoded strings in SQLite
- `ConfigurationManager.cleanupCorruptedConfigurations()` removes invalid entries

### Common Patterns

**Database Access:**
```swift
// Always use try/catch with DatabaseManager
do {
    try DatabaseManager.shared.insertMeeting(meeting)
} catch {
    print("❌ Error: \(error)")
}
```

**Color Usage:**
```swift
// ALWAYS use grayscale or semantic colors
.foregroundColor(Color(white: 0.93))  // ✅ Good
.foregroundColor(Color.blue)          // ❌ Bad (except status indicators)
```

**Keyword Filtering:**
```swift
// Empty keywords = fetch all messages
if config.shouldFilterByKeywords {
    return config.matchesKeywords(message.text)
}
return true
```
