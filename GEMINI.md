# GEMINI.md

This file provides guidance to Gemini when working with code in this repository.

## Project Overview

Aumeno is a native macOS application built with SwiftUI. It's designed to fetch meeting notifications from Slack, parse them, and provide a dedicated, floating note-taking window for each meeting. The app supports multiple Slack workspaces, allows for manual meeting creation, and features a minimalist dark-theme UI.

### Core Technologies

*   **UI:** SwiftUI
*   **Architecture:** MVVM (Model-View-ViewModel)
*   **Database:** SQLite (via GRDB.swift, inferred from common Swift practices, though not explicitly confirmed)
*   **Language:** Swift

### Key Features

*   **Slack Integration:** Fetches messages from configured Slack channels.
*   **Multi-Workspace:** Supports multiple Slack workspace configurations.
*   **Meeting Notes:** Provides a floating window for taking notes during meetings.
*   **Manual Meetings:** Allows users to create meetings that are not from Slack.
*   **Keyword Filtering:** Filters Slack messages based on user-defined keywords.
*   **Onboarding:** A first-launch wizard to guide users through setting up Slack integration.

## Building and Running

This is an Xcode project. All build and run operations should be performed through Xcode or the `xcodebuild` command-line tool.

### Build Commands

```bash
# Build for debugging
xcodebuild -project Aumeno.xcodeproj -scheme Aumeno -configuration Debug build

# Build for release
xcodebuild -project Aumeno.xcodeproj -scheme Aumeno -configuration Release build
```

### Running the App

The app can be run directly from Xcode (Cmd+R).

## Code Architecture

The project follows the MVVM design pattern.

*   **Models:** (`Aumeno/Models`) Plain Swift structs that represent the application's data (e.g., `Meeting`, `SlackConfiguration`).
*   **Views:** (`Aumeno/Views`) SwiftUI views that compose the application's user interface. `MeetingListView.swift` is the main view of the application.
*   **ViewModels:** (`Aumeno/ViewModels`) Classes that hold the presentation logic and state. `MeetingViewModel.swift` is the primary view model.
*   **Services:** (`Aumeno/Services`) Classes that handle business logic, such as fetching data from Slack (`SlackService`), managing the database (`DatabaseManager`, `ConfigurationManager`), and scheduling notifications (`MeetingScheduler`).
*   **App Entry Point:** (`Aumeno/AumenoApp.swift`) The main entry point of the application.

## Development Conventions

*   **UI:** The application uses a dark theme with a specific color palette. Refer to `MeetingListView.swift` for examples of color usage.
*   **Database:** Database interactions are handled by `DatabaseManager.swift` and `ConfigurationManager.swift`.
*   **Concurrency:** The app uses Swift's modern concurrency features (async/await) for tasks like network requests.
*   **Dependencies:** Dependencies are managed by Xcode's Swift Package Manager.
