import SwiftUI

/// Navigation item in the sidebar
enum DashboardTab: String, CaseIterable {
    case home = "Home"
    case history = "历史"
    case smartPhrases = "智能短语"
    case customWords = "易错词"
    case settings = "设置"

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .history:
            return "clock.arrow.circlepath"
        case .smartPhrases:
            return "text.bubble.fill"
        case .customWords:
            return "character.book.closed"
        case .settings:
            return "gearshape.fill"
        }
    }

    var label: String {
        return self.rawValue
    }
}

/// Sidebar component for the dashboard
struct DashboardSidebar: View {
    @Binding var selectedTab: DashboardTab
    
    var body: some View {
        VStack(spacing: 0) {
            // App Logo and Name
            appHeader
                .padding(.vertical, 16)
            
            // Navigation Items
            navigationSection
                .padding(.top, 8)
            
            Spacer()
        }
        .frame(width: 200)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Components
    
    private var appHeader: some View {
        HStack(spacing: 10) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            Text("MicOver")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    private var navigationSection: some View {
        VStack(spacing: 4) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                NavigationItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
        }
        .padding(.horizontal, 8)
    }
}

/// Individual navigation item in the sidebar
struct NavigationItem: View {
    let tab: DashboardTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 18)

                Text(tab.label)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .primary : .primary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(
                HStack {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                        .frame(width: 3)
                    Spacer()
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 0) {
        DashboardSidebar(selectedTab: .constant(.home))
        
        Spacer()
    }
    .frame(width: 600, height: 500)
}
