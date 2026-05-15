import SwiftUI

struct ContentView: View {
    @ObservedObject var manager = AppManager.shared
    
    var body: some View {
        TabView {
            // SEZIONE APPS
            AppsView()
                .tabItem {
                    Label("Apps", systemImage: "square.grid.2x2.fill")
                }
            
            // SEZIONE INSTALL
            InstallView()
                .tabItem {
                    Label("Installa", systemImage: "plus.circle.fill")
                }
            
            // SEZIONE SETTINGS
            SettingsView()
                .tabItem {
                    Label("Impostazioni", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
        .toolbar {
            if !manager.isInstalling {
                Button {
                    manager.refreshAll()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}
