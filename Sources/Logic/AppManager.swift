import Foundation
import SwiftUI

class AppManager: ObservableObject {
    
    // MARK: - App State
    @Published var installedApps: [AppItem] = []
    @Published var isInstalling: Bool = false
    @Published var installationProgress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    
    // MARK: - Auth State
    @Published var isAuthenticated: Bool = false
    @Published var isShowing2FA: Bool = false
    @Published var authTicket: String?
    @Published var appleSession: AppleSession?
    
    // MARK: - Security Scan State
    @Published var pendingIpaURL: URL?
    @Published var pendingMetadata: IPAMetadata?
    @Published var securityReport: SecurityReport?
    @Published var showSecurityAlert: Bool = false
    
    init() {
        installedApps = []
        loadSavedApps()
    }
    
    // MARK: - Persistenza
    
    func loadSavedApps() {
        if let data = UserDefaults.standard.data(forKey: "saved_apps"),
           let apps = try? JSONDecoder().decode([AppItem].self, from: data) {
            installedApps = apps
        }
    }
    
    func saveApps() {
        if let data = try? JSONEncoder().encode(installedApps) {
            UserDefaults.standard.set(data, forKey: "saved_apps")
        }
    }
    
    // MARK: - Flusso di Installazione
    
    /// Step 1: Scansiona l'IPA. Se è sicuro, procede. Se no, mostra alert.
    func beginInstall(at url: URL) {
        isInstalling = true
        installationProgress = 0.05
        statusMessage = "Scansione sicurezza in corso..."
        
        // Copia subito l'URL mentre abbiamo il permesso
        let fileManager = FileManager.default
        let localCopy = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).ipa")
        
        guard (try? fileManager.copyItem(at: url, to: localCopy)) != nil else {
            isInstalling = false
            errorMessage = "Impossibile accedere al file. Riprova."
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Prima leggiamo i metadati
            let parseResult = IPAParser.parse(at: localCopy)
            
            // Poi eseguiamo la scansione sicurezza
            let report = SecurityScanner.scan(at: localCopy)
            
            DispatchQueue.main.async {
                switch parseResult {
                case .failure(let error):
                    self.isInstalling = false
                    self.errorMessage = "IPA non valida: \(error.localizedDescription)"
                    try? fileManager.removeItem(at: localCopy)
                    
                case .success(let metadata):
                    self.pendingIpaURL = localCopy
                    self.pendingMetadata = metadata
                    self.securityReport = report
                    self.installationProgress = 0.15
                    
                    if report.isSafe {
                        // Nessun problema trovato → installa direttamente
                        self.proceedWithInstall()
                    } else {
                        // Trovati warning o danger → mostra alert all'utente
                        self.isInstalling = false
                        self.showSecurityAlert = true
                    }
                }
            }
        }
    }
    
    /// Step 2: L'utente ha confermato dopo la scansione di sicurezza
    func proceedWithInstall() {
        guard let url = pendingIpaURL, let metadata = pendingMetadata else { return }
        
        // Verifica autenticazione
        guard let session = appleSession else {
            isInstalling = false
            errorMessage = "Prima devi accedere con il tuo Apple ID nelle Impostazioni."
            return
        }
        
        isInstalling = true
        statusMessage = "Preparazione firma..."
        installationProgress = 0.2
        
        Task {
            do {
                let signed = try await SigningEngine.sign(
                    ipaURL: url,
                    metadata: metadata,
                    session: session,
                    progress: { progress, message in
                        Task { @MainActor in
                            self.installationProgress = 0.2 + (progress * 0.7)
                            self.statusMessage = message
                        }
                    }
                )
                
                await MainActor.run {
                    self.installationProgress = 0.95
                    self.statusMessage = "Aggiunta alla lista..."
                    
                    let newApp = AppItem(
                        name: signed.appName,
                        bundleId: signed.bundleId,
                        version: signed.version,
                        iconName: "app.badge.fill",
                        daysRemaining: 7
                    )
                    
                    self.installedApps.append(newApp)
                    self.saveApps()
                    
                    self.installationProgress = 1.0
                    self.statusMessage = "✅ Installazione completata!"
                    
                    // Apri il file IPA firmato con il sistema iOS
                    self.openSignedIPA(at: signed.ipaURL)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.isInstalling = false
                        self.pendingIpaURL = nil
                        self.pendingMetadata = nil
                    }
                }
            } catch {
                await MainActor.run {
                    self.isInstalling = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Annulla l'installazione in corso
    func cancelInstall() {
        if let url = pendingIpaURL {
            try? FileManager.default.removeItem(at: url)
        }
        pendingIpaURL = nil
        pendingMetadata = nil
        securityReport = nil
        showSecurityAlert = false
        isInstalling = false
        installationProgress = 0
        statusMessage = ""
    }
    
    // Apre l'IPA firmata tramite il sistema iOS per l'installazione effettiva
    private func openSignedIPA(at url: URL) {
        // iOS aprirà il pannello di installazione nativo
        // Questo richiede che l'app sia distribuita con entitlements corretti
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                // Fallback: salviamo l'IPA nella cartella Files dell'app
                print("IPA salvata in: \(url.path)")
            }
        }
    }
    
    // MARK: - Autenticazione Apple
    
    func login(appleId: String, password: String, anisetteUrl: String) {
        statusMessage = "Connessione ad Apple..."
        
        Task {
            do {
                let anisette = try await AnisetteClient.fetchHeaders(from: anisetteUrl)
                let session = try await GrandSlamAuth.authenticate(
                    appleId: appleId,
                    password: password,
                    anisetteData: anisette
                )
                
                await MainActor.run {
                    self.appleSession = session
                    self.isAuthenticated = true
                    self.statusMessage = "✅ Accesso effettuato come \(appleId)"
                }
            } catch GrandSlamError.twoFactorRequired(let ticket) {
                await MainActor.run {
                    self.authTicket = ticket
                    self.isShowing2FA = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func submit2FA(code: String, appleId: String, anisetteUrl: String) {
        guard let ticket = authTicket else { return }
        
        Task {
            do {
                let anisette = try await AnisetteClient.fetchHeaders(from: anisetteUrl)
                let session = try await GrandSlamAuth.verify2FA(
                    code: code,
                    sessionId: ticket,
                    anisetteData: anisette
                )
                
                // Ricrea la sessione con l'Apple ID corretto
                let fullSession = AppleSession(appleId: appleId, token: session.token, expiry: session.expiry)
                
                await MainActor.run {
                    self.appleSession = fullSession
                    self.isAuthenticated = true
                    self.isShowing2FA = false
                    self.statusMessage = "✅ Autenticato con successo!"
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Codice 2FA non valido."
                }
            }
        }
    }
    
    func logout() {
        appleSession = nil
        isAuthenticated = false
        authTicket = nil
    }
    
    // MARK: - Gestione App

    func refreshAll() {
        for i in 0..<installedApps.count {
            installedApps[i].daysRemaining = 7
        }
        saveApps()
    }
    
    func deleteApp(at offsets: IndexSet) {
        installedApps.remove(atOffsets: offsets)
        saveApps()
    }
}
