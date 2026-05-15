import SwiftUI

struct ContentView: View {
    @StateObject private var manager = AppManager()
    
    var body: some View {
        TabView {
            // SEZIONE APPS
            NavigationStack {
                AppsView(manager: manager)
                    .navigationTitle("Le mie App")
                    .toolbar {
                        Button {
                            manager.refreshAll()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
            }
            .tabItem {
                Label("Apps", systemImage: "square.grid.2x2.fill")
            }
            
            // SEZIONE INSTALL
            NavigationStack {
                InstallView(manager: manager)
                    .navigationTitle("Installa IPA")
            }
            .tabItem {
                Label("Install", systemImage: "plus.circle.fill")
            }
            
            // SEZIONE SETTINGS
            NavigationStack {
                SettingsView(manager: manager)
                    .navigationTitle("Impostazioni")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
}
