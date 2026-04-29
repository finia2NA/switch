import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 460, height: 280)
    }
}

private struct GeneralTab: View {
    var body: some View {
        Form {
            Text("Settings")
                .font(.title3)
        }
        .padding(20)
    }
}
