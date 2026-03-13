import SwiftUI

/// A view that renders drill instructions with rich markdown formatting and engaging design
struct DrillInstructionsView: View {
    let instructions: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            ForEach(parsedSections, id: \.title) { section in
                DrillSection(section: section)
            }
        }
    }

    private var parsedSections: [DrillSectionData] {
        parseMarkdown(instructions)
    }
}

// MARK: - Data Models

struct DrillSectionData: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let content: [DrillContentItem]
    let color: Color
}

enum DrillContentItem {
    case text(String)
    case numberedList([String])
    case bulletList([String])
}

// MARK: - Section View

struct DrillSection: View {
    let section: DrillSectionData

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section Header
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: section.icon)
                    .font(.title3)
                    .foregroundColor(section.color)

                Text(section.title)
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()
            }
            .padding(.bottom, DesignSystem.Spacing.xs)

            // Section Content
            ForEach(Array(section.content.enumerated()), id: \.offset) { _, item in
                contentView(for: item)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(section.color.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func contentView(for item: DrillContentItem) -> some View {
        switch item {
        case .text(let text):
            Text(text)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

        case .numberedList(let items):
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(section.color.opacity(0.15))
                                .frame(width: 28, height: 28)

                            Text("\(index + 1)")
                                .font(DesignSystem.Typography.labelMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(section.color)
                        }
                        .frame(width: 28, height: 28)

                        Text(item)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        Circle()
                            .fill(section.color)
                            .frame(width: 6, height: 6)
                            .padding(.top, 8)

                        Text(item)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Markdown Parser

private func parseMarkdown(_ markdown: String) -> [DrillSectionData] {
    var sections: [DrillSectionData] = []

    // Split by double newlines to get sections
    let lines = markdown.components(separatedBy: "\n")
    var currentSection: (title: String, lines: [String])? = nil

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Check if this is a section header (bold text followed by colon)
        if trimmed.hasPrefix("**") && trimmed.contains(":**") {
            // Save previous section if exists
            if let section = currentSection {
                sections.append(createSection(title: section.title, lines: section.lines))
            }

            // Extract section title
            let title = trimmed
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)

            currentSection = (title: title, lines: [])
        } else if !trimmed.isEmpty {
            // Add line to current section
            if currentSection != nil {
                currentSection?.lines.append(trimmed)
            }
        }
    }

    // Add last section
    if let section = currentSection {
        sections.append(createSection(title: section.title, lines: section.lines))
    }

    return sections
}

private func createSection(title: String, lines: [String]) -> DrillSectionData {
    // Determine icon and color based on section title
    let (icon, color) = iconAndColor(for: title)

    // Parse content items
    var contentItems: [DrillContentItem] = []
    var currentList: [String] = []
    var isNumberedList = false
    var isBulletList = false

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Check for numbered list item (starts with digit followed by period or parenthesis)
        if trimmed.range(of: "^\\d+[.):]", options: .regularExpression) != nil {
            // Extract the content after the number
            let content = trimmed.replacingOccurrences(of: "^\\d+[.):] *", with: "", options: .regularExpression)

            if !isNumberedList {
                // Start new numbered list
                if !currentList.isEmpty && isBulletList {
                    contentItems.append(.bulletList(currentList))
                    currentList = []
                }
                isNumberedList = true
                isBulletList = false
            }
            currentList.append(content)
        }
        // Check for bullet list item (starts with bullet, dash, or asterisk)
        else if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
            let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)

            if !isBulletList {
                // Start new bullet list
                if !currentList.isEmpty && isNumberedList {
                    contentItems.append(.numberedList(currentList))
                    currentList = []
                }
                isBulletList = true
                isNumberedList = false
            }
            currentList.append(content)
        }
        // Regular text
        else {
            // Flush any current list
            if !currentList.isEmpty {
                if isNumberedList {
                    contentItems.append(.numberedList(currentList))
                } else if isBulletList {
                    contentItems.append(.bulletList(currentList))
                }
                currentList = []
                isNumberedList = false
                isBulletList = false
            }
            contentItems.append(.text(trimmed))
        }
    }

    // Flush remaining list
    if !currentList.isEmpty {
        if isNumberedList {
            contentItems.append(.numberedList(currentList))
        } else if isBulletList {
            contentItems.append(.bulletList(currentList))
        }
    }

    return DrillSectionData(title: title, icon: icon, content: contentItems, color: color)
}

private func iconAndColor(for title: String) -> (String, Color) {
    let lowercased = title.lowercased()

    if lowercased.contains("setup") {
        return ("map", DesignSystem.Colors.primaryGreen)
    } else if lowercased.contains("instruction") {
        return ("list.number", DesignSystem.Colors.accentOrange)
    } else if lowercased.contains("coaching") || lowercased.contains("points") {
        return ("lightbulb", Color.yellow)
    } else if lowercased.contains("progression") || lowercased.contains("variation") {
        return ("arrow.up.right", Color.purple)
    } else if lowercased.contains("safety") {
        return ("exclamationmark.shield", Color.red)
    } else if lowercased.contains("generated") || lowercased.contains("request") {
        return ("info.circle", Color.blue)
    } else {
        return ("doc.text", DesignSystem.Colors.textSecondary)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        DrillInstructionsView(instructions: """
**Setup:**
Set up a 10x10 meter square area using four cones. Place a ball at the starting position.

**Instructions:**
1. Standing at the bottom left cone, dribble the ball to the top left cone in a straight line.
2. From the top left cone, dribble diagonally to the bottom right cone.
3. At the bottom right cone, perform a sharp turn and dribble back to the starting position.

**Coaching Points:**
• Keep your head up between touches to scan the area
• Use the inside of your foot for better control
• Focus on quick, light touches rather than heavy kicks

**Progressions:**
• Easier: Increase cone spacing to 12x12 meters
• Harder: Add a defender applying light pressure
""")
        .padding()
    }
}
