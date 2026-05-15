import SwiftUI

struct SettingsView: View {
    @StateObject private var manager = AppManager.shared
    @AppStorage("apple_id") private var appleId = ""
    @State private var password = ""
    @State private var showing2FA = false
    @State private var twoFactorCode = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if manager.isLoggedIn {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(appleId)
                                    .font(.headline)
                                Text("Sessione Attiva")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Esci") {
                                manager.logout()
                            }
                            .foregroundStyle(.red)
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 15) {
                            TextField("Apple ID", text: $appleId)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(.roundedBorder)
                            
                            if manager.isAuthenticating {
                                ProgressView()
                            } else {
                                Button(action: login) {
                                    Text("Accedi")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                } header: {
                    Text("Account Apple")
                } footer: {
                    Text("Usa una 'Password per le app' se hai la 2FA attiva per evitare blocchi di sicurezza.")
                }
                
                Section {
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text("1.0.0 (Beta)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Informazioni")
                }
            }
            .navigationTitle("Impostazioni")
            .sheet(isPresented: $showing2FA) {
                twoFactorSheet
            }
            .alert("Errore", isPresented: .init(get: { manager.lastError != nil }, set: { _ in manager.lastError = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = manager.lastError {
                    Text(error)
                }
            }
        }
    }
    
    private var twoFactorSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Verifica Dispositivo")
                    .font(.title2.bold())
                
                Text("Inserisci il codice a 6 cifre inviato ai tuoi dispositivi Apple.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                
                TextField("000000", text: $twoFactorCode)
                    .font(.system(size: 40, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                
                Button("Verifica") {
                    Task {
                        await manager.verify2FA(code: twoFactorCode)
                        showing2FA = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(twoFactorCode.count < 6)
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Annulla") { showing2FA = false })
        }
        .presentationDetents([.medium])
    }
    
    private func login() {
        Task {
            await manager.login(appleId: appleId, password: password)
            if manager.lastError?.contains("2FA") == true || manager.lastError?.contains("due fattori") == true {
                showing2FA = true
            }
        }
    }
}
