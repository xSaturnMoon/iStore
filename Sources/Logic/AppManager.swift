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
    
    // MARK: - Autenticazione Automatica
    
    func login(appleId: String, password: String) async {
        await MainActor.run {
            self.isAuthenticating = true
            self.lastError = nil
        }
        
        do {
            // Otteniamo i dati Anisette dal tuo PC
            let anisette = try await AnisetteClient.fetchHeaders(from: proxyUrl)
            
            // Effettuiamo il login tramite il proxy sul tuo PC
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
                self.lastError = "Richiesta 2FA" // Innesca lo sheet in UI
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
            await MainActor.run {
                self.lastError = "Codice 2FA errato."
            }
        }
    }
    
    func logout() {
        appleSession = nil
        isLoggedIn = false
        authTicket = nil
    }

    // MARK: - Logica App & Installazione (Semplificata)
    
    private func loadSavedApps() {
        if let data = UserDefaults.standard.data(forKey: "saved_apps"),
           let apps = try? JSONDecoder().decode([AppItem].self, from: data) {
            installedApps = apps
        }
    }
    
    func beginInstall(at url: URL) {
        // Logica di installazione IPA già implementata...
        self.pendingIpaURL = url
        // Procedi con scan -> sign -> install
    }
}

// Estensione per gestire vecchi riferimenti nel codice UI
extension AppManager {
    var isShowing2FA: Bool {
        get { lastError == "Richiesta 2FA" }
        set { if !newValue { lastError = nil } }
    }
}
