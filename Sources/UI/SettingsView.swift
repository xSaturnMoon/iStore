import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: AppManager
    @AppStorage("anisette_url") private var anisetteUrl = "https://anisette.sidecloud.xyz/"
    @AppStorage("apple_id") private var appleId = ""
    @AppStorage("auto_refresh") private var autoRefresh = true
    @State private var appPassword = ""
    @State private var twoFACode = ""
    @State private var showLogoutConfirm = false
    
    var body: some View {
        Form {
            
            // MARK: - Account Apple
            Section {
                if manager.isAuthenticated {
                    authenticatedRow
                } else {
                    loginForm
                }
            } header: {
                Label("Account Apple", systemImage: "person.crop.circle")
            }
            
            // MARK: - 2FA (appare solo quando richiesto)
            if manager.isShowing2FA {
                Section {
                    twoFAForm
                } header: {
                    Label("Verifica in due passaggi", systemImage: "lock.shield")
                } footer: {
                    Text("Inserisci il codice a 6 cifre che hai ricevuto sui tuoi dispositivi Apple.")
                }
            }
            
            // MARK: - Server Anisette
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("URL Server Anisette")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://...", text: $anisetteUrl)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
            } header: {
                Label("Configurazione Server", systemImage: "server.rack")
            } footer: {
                Text("Il server Anisette fornisce i dati di autenticazione necessari ad Apple. Usa un server pubblico o il tuo.")
            }
            
            // MARK: - Automazione
            Section {
                Toggle(isOn: $autoRefresh) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Refresh Automatico")
                        Text("Rinnova le firme ogni 6 giorni")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label("Automazione", systemImage: "arrow.clockwise.circle")
            }
            
            // MARK: - Info
            Section {
                VStack(spacing: 6) {
                    Text("iStore")
                        .font(.headline)
                    Text("v1.0.0 — by xSaturnMoon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Build via GitHub Actions + Xcode 26")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }
        }
        .alert("Errore", isPresented: Binding(
            get: { manager.errorMessage != nil },
            set: { _ in manager.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(manager.errorMessage ?? "")
        }
        .confirmationDialog("Esci dall'account?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Esci", role: .destructive) { manager.logout() }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Dovrai effettuare di nuovo l'accesso per installare nuove app.")
        }
    }
    
    // MARK: - Subviews
    
    private var authenticatedRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(manager.appleSession?.appleId ?? appleId)
                    .font(.subheadline.bold())
                if let expiry = manager.appleSession?.expiry {
                    Text("Sessione valida fino a \(expiry.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                showLogoutConfirm = true
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var loginForm: some View {
        Group {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                TextField("Apple ID (email)", text: $appleId)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
            
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                SecureField("Password o Password App", text: $appPassword)
            }
            
            Button {
                manager.login(appleId: appleId, password: appPassword, anisetteUrl: anisetteUrl)
            } label: {
                HStack {
                    Spacer()
                    if manager.statusMessage.contains("Connessione") {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Accedi con Apple ID")
                            .bold()
                    }
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.blue)
            .disabled(appleId.isEmpty || appPassword.isEmpty)
        }
    }
    
    private var twoFAForm: some View {
        Group {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                TextField("Codice a 6 cifre", text: $twoFACode)
                    .keyboardType(.numberPad)
                    .font(.system(.body, design: .monospaced))
            }
            
            Button {
                manager.submit2FA(code: twoFACode, appleId: appleId, anisetteUrl: anisetteUrl)
                twoFACode = ""
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                    Text("Verifica Codice")
                        .bold()
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.orange)
            .disabled(twoFACode.count < 6)
        }
    }
}
