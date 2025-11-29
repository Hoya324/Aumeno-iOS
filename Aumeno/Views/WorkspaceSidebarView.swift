//
//  WorkspaceSidebarView.swift
//  Aumeno
//
//  Created by Hoya324
//

import SwiftUI
import AppKit // For NSColor

struct WorkspaceSidebarView: View {
    let workspaces: [SlackConfiguration]
    let selectedWorkspace: String?
    let onSelect: (String?) -> Void
    let onAddWorkspace: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // All button
            WorkspaceIconButton(
                title: "All",
                icon: "square.grid.2x2",
                isSelected: selectedWorkspace == nil,
                count: nil
            ) {
                onSelect(nil)
            }

            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.vertical, 4)

            // Workspace icons
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(workspaces) { workspace in
                        WorkspaceIconButton(
                            title: workspace.name,
                            channelName: workspace.channelName,
                            icon: nil,
                            color: workspace.color,
                            isSelected: selectedWorkspace == workspace.id,
                            count: nil // TODO: Add unread count
                        ) {
                            onSelect(workspace.id)
                        }
                    }
                }
            }

            Spacer()

            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.vertical, 4)

            // Add workspace button
            Button(action: onAddWorkspace) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.gray.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Add Workspace")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(width: 60)
        .background(Color(red: 0.09, green: 0.09, blue: 0.09))
    }
}

// MARK: - Workspace Icon Button

struct WorkspaceIconButton: View {
    let title: String
    var channelName: String? = nil
    var icon: String? = nil
    var color: String? = nil
    let isSelected: Bool
    let count: Int?
    let action: () -> Void

    @State private var isHovering = false
    
    private var backgroundColor: Color {
        if let hex = color, let nsColor = NSColor(hex: hex) {
            return Color(nsColor)
        }
        return Color(white: 0.2)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? backgroundColor.opacity(0.8) : backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                        )

                    if let iconName = icon {
                        Image(systemName: iconName)
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(Color(white: 0.93))
                    } else {
                        // Show first letter of workspace name
                        Text(title.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color(white: 0.93))
                    }
                }
                .frame(width: 42, height: 42)
                .scaleEffect(isHovering ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isHovering)

                // Notification badge
                if let count = count, count > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.pink)
                            .frame(width: 20, height: 20)

                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help(channelName != nil ? "\(title) > \(channelName!)" : title)
    }
}

// MARK: - Preview

#Preview {
    WorkspaceSidebarView(
        workspaces: [
            SlackConfiguration(name: "테스트", channelName: "일반", token: "xoxb-test", channelID: "C123", color: "#4A90E2"),
            SlackConfiguration(name: "회사", channelName: "개발", token: "xoxb-test", channelID: "C456", color: "#F5A623")
        ],
        selectedWorkspace: nil,
        onSelect: { _ in },
        onAddWorkspace: {}
    )
    .frame(height: 600)
}

