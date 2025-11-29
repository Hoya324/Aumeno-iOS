//
//  ButtonStyles.swift
//  Aumeno
//
//  Created by Hoya324
//

import SwiftUI

// MARK: - Button Styles (Dark Theme)

struct DarkPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Color(white: 0.93))
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(configuration.isPressed ? 0.5 : 0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DarkSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(Color(white: 0.67))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(configuration.isPressed ? 0.4 : 0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PlainCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .background(configuration.isPressed ? Color.gray.opacity(0.3) : Color.clear)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - TextField Styles (Dark Theme)

struct DarkTextFieldStyle: TextFieldStyle {
    var isMono: Bool = false
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 12, design: isMono ? .monospaced : .default))
            .padding(8)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .cornerRadius(6)
    }
}

// Keep legacy button styles for backwards compatibility
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DarkPrimaryButtonStyle().makeBody(configuration: configuration)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DarkSecondaryButtonStyle().makeBody(configuration: configuration)
    }
}