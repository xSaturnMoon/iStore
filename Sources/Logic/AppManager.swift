import Foundation
import SwiftUI

class AppManager: ObservableObject {
    static let shared = AppManager()
    
    // MARK: - App State
    @Published var installedApps: [AppItem] = []
    @Published var isInstalling: Bool = false
    @Published var installationProgress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var lastError: String?
    
    // MARK: - Auth State
    @Published var isLoggedIn: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var authTicket: String?
    @Published var appleSession: AppleSession?
    
    // MARK: - Security Scan State
    @Published var pendingIpaURL: URL?
    @Published var pendingMetadata: IPAMetadata?
    @Published var securityReport: SecurityReport?
    @Published var showSecurityAlert: Bool = false
    
    // URL del proxy locale (il tuo PC)
    private let proxyUrl = "http://192.168.1.27:3000"
    
    init() {
        loadSavedApps()
    }
    
    // MARK: - Autenticazione
    
    func login(appleId: String, password: String) async {
        await MainActor.run {
            self.isAuthenticating = true
            self.lastError = nil
        }
        
        do {
            let anisette = try await AnisetteClient.fetchHeaders(from: proxyUrl)
            let session = try await GrandSlamAuth.authenticate(
                appleId: appleId,
                password: password,
                anisetteData: anisette,
                anisetteBaseURL: proxyUrl
            )
            
            await MainActor.run {
                self.appleSession = session
                self.isLoggedIn = true
                self.isAuthenticating = false
                self.statusMessage = "✅ Accesso effettuato"
            }
        } catch GrandSlamError.twoFactorRequired(let ticket) {
            await MainActor.run {
                self.authTicket = ticket
                self.isAuthenticating = false
                self.lastError = "Richiesta 2FA"
            }
        } catch {
            await MainActor.run {
                self.isAuthenticating = false
                self.lastError = error.localizedDescription
            }
        }
    }
    
    func verify2FA(code: String) async {
        guard let ticket = authTicket else { return }
        do {
            let anisette = try await AnisetteClient.fetchHeaders(from: proxyUrl)
            let session = try await GrandSlamAuth.verify2FA(
                code: code,
                sessionId: ticket,
                anisetteData: anisette,
                anisetteBaseURL: proxyUrl
            )
            await MainActor.run {
                self.appleSession = session
                self.isLoggedIn = true
                self.isShowing2FA = false
            }
        } catch {
            await MainActor.run { self.lastError = "Codice 2FA errato." }
        }
    }
    
    func logout() {
        appleSession = nil
        isLoggedIn = false
        authTicket = nil
    }

    // MARK: - Flusso di Installazione
    
    func beginInstall(at url: URL) {
        guard isLoggedIn else {
            self.lastError = "Devi prima accedere con il tuo Apple ID nelle Impostazioni."
            return
        }
        
        self.isInstalling = true
        self.statusMessage = "Scansione sicurezza..."
        self.installationProgress = 0.1
        
        Task {
            // Correzione label: 'at' invece di 'ipaURL'
            let report = SecurityScanner.scan(at: url)
            let metadata = IPAParser.parse(ipaURL: url)
            
            await MainActor.run {
                self.pendingIpaURL = url
                self.pendingMetadata = metadata
                self.securityReport = report
                self.installationProgress = 0.3
                
                if !report.isSafe {
                    self.showSecurityAlert = true
                } else {
                    self.proceedWithInstall()
                }
            }
        }
    }
    
    func proceedWithInstall() {
        guard let url = pendingIpaURL, 
              let session = appleSession, 
              let metadata = pendingMetadata else { return }
        
        self.statusMessage = "Firma in corso..."
        self.installationProgress = 0.5
        
        Task {
            do {
                // Aggiunta parametri mancanti a SigningEngine.sign
                let signedIPA = try await SigningEngine.sign(
                    ipaURL: url,
                    metadata: metadata,
                    session: session,
                    progress: { prog, msg in
                        DispatchQueue.main.async {
                            self.installationProgress = 0.5 + (prog * 0.3)
                            self.statusMessage = msg
                        }
                    }
                )
                
                await MainActor.run {
                    self.statusMessage = "Installazione su iOS..."
                    self.installationProgress = 0.9
                }
                
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    let newApp = AppItem(name: metadata.name, bundleId: metadata.bundleId, version: metadata.version, daysRemaining: 7)
                    self.installedApps.append(newApp)
                    self.saveApps()
                    
                    self.isInstalling = false
                    self.statusMessage = "✅ Installata!"
                    self.installationProgress = 1.0
                }
            } catch {
                await MainActor.run {
                    self.isInstalling = false
                    self.lastError = "Errore: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Funzioni UI
    
    func refreshAll() {
        // Simula il refresh dei giorni rimanenti
        for i in 0..<installedApps.count {
            installedApps[i].daysRemaining = 7
        }
        saveApps()
    }
    
    func deleteApp(at offsets: IndexSet) {
        installedApps.remove(atOffsets: offsets)
        saveApps()
    }
    
    // MARK: - Persistenza
    
    private func loadSavedApps() {
        if let data = UserDefaults.standard.data(forKey: "saved_apps"),
           let apps = try? JSONDecoder().decode([AppItem].self, from: data) {
            installedApps = apps
        }
    }
    
    private func saveApps() {
        if let data = try? JSONEncoder().encode(installedApps) {
            UserDefaults.standard.set(data, forKey: "saved_apps")
        }
    }
}

extension AppManager {
    var isShowing2FA: Bool {
        get { lastError == "Richiesta 2FA" }
        set { if !newValue { lastError = nil } }
    }
}
