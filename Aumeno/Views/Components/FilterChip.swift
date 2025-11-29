//
//  FilterChip.swift
//  Aumeno
//
//  Created by Gemini
//

import SwiftUI

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? Color(white: 0.93) : Color(white: 0.60))
                }
            }
            .foregroundColor(isSelected ? Color(white: 0.93) : Color(white: 0.67))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
