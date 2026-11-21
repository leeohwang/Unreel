import SwiftUI

/// Native tab row. Instagram's mobile site hides its own tab bar on the
/// messages page, and its back arrow leads to the (blocked) feed, so without
/// this there is no way out of DMs.
struct TabBar: View {
    @ObservedObject var navigator: WebNavigator
    let showHome: Bool

    private struct Tab: Identifiable {
        let id: String
        let title: String
        let icon: String
        let path: String?   // nil = own profile
        let matches: (String) -> Bool
    }

    private var tabs: [Tab] {
        var list: [Tab] = []
        if showHome {
            list.append(Tab(id: "home", title: "Home", icon: "house", path: "/", matches: { $0 == "/" }))
        }
        list += [
            Tab(id: "dm", title: "Messages", icon: "paperplane", path: "/direct/inbox/",
                matches: { $0.hasPrefix("/direct") }),
            Tab(id: "search", title: "Search", icon: "magnifyingglass", path: "/explore/search/",
                matches: { $0.hasPrefix("/explore") }),
            Tab(id: "activity", title: "Activity", icon: "heart", path: "/accounts/activity/",
                matches: { $0.hasPrefix("/accounts/activity") || $0.hasPrefix("/notifications") }),
            Tab(id: "profile", title: "Profile", icon: "person.crop.circle", path: nil, matches: { _ in false }),
        ]
        return list
    }

    var body: some View {
        HStack {
            let pathMatch = tabs.first { $0.matches(navigator.currentPath) }?.id
            let selectedID = pathMatch ?? navigator.lastTappedTab
            ForEach(tabs) { tab in
                let selected = tab.id == selectedID
                Button {
                    navigator.lastTappedTab = tab.id
                    if let path = tab.path { navigator.go(path) } else { navigator.goProfile() }
                } label: {
                    // Icons only, like Instagram's own bar.
                    Image(systemName: selected && tab.id != "search" ? tab.icon + ".fill" : tab.icon)
                        .font(.system(size: 24, weight: selected ? .semibold : .regular))
                        .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(Color.primary)
                }
                .accessibilityLabel(tab.title)
            }
        }
        .padding(.top, 2)
        .background(Color(uiColor: .systemBackground))
    }
}
