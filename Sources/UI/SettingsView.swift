import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: AppManager
    @AppStorage("anisette_url") private var anisetteUrl = "https://anisette.example.com"
    @AppStorage("apple_id") private var appleId = ""
    @AppStorage("auto_refresh") private var autoRefresh = true
    
    var body: some View {
        Form {
            Section("Account Apple") {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(.blue)
                    TextField("Apple ID", text: $appleId)
                }
                
                NavigationLink {
                    Text("Gestione Password Sicura")
                } label: {
                    Text("Password App")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Configurazione Server") {
                VStack(alignment: .leading) {
                    Text("URL Anisette")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://...", text: $anisetteUrl)
                        .font(.system(.body, design: .monospaced))
                }
                
                Button {
                    // Test connessione
                } label: {
                    Label("Test Connessione Server", systemImage: "network")
                }
            }
            
            Section("Automazione") {
                Toggle(isOn: $autoRefresh) {
                    VStack(alignment: .leading) {
                        Text("Refresh Automatico")
                        Text("Rinnova le firme ogni 6 giorni")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section {
                Button(role: .destructive) {
                    // Log out
                } label: {
                    CenterText("Esci dall'account")
                }
            }
            
            Section {
                VStack(spacing: 8) {
                    Text("iStore for xSaturnMoon")
                        .font(.caption)
                        .bold()
                    Text("Versione 1.0.0 (Gold Master)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
    }
}

struct CenterText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack {
            Spacer()
            Text(text)
            Spacer()
        }
    }
}
