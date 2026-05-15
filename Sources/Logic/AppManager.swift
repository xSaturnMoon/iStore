import SwiftUI
import Combine

struct AppItem: Identifiable, Codable {
    var id = UUID()
    let name: String
    let bundleId: String
    let version: String
    let iconName: String
    var daysRemaining: Int
    var isSystemApp: Bool = false
}

class AppManager: ObservableObject {
    @Published var installedApps: [AppItem] = []
    @Published var isInstalling: Bool = false
    @Published var installationProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var statusMessage: String = ""
    
    init() {
        // Inizialmente vuoto, caricherai tu le tue app vere
        installedApps = []
    }
    
    func installIPA(at url: URL) {
        isInstalling = true
        errorMessage = nil
        statusMessage = "Copia file in corso..."
        installationProgress = 0.1
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = IPAParser.parse(at: url)
            
            DispatchQueue.main.async {
                switch result {
                case .success(let metadata):
                    self.statusMessage = "Firma in corso..."
                    self.installationProgress = 0.6
                    
                    let newApp = AppItem(
                        name: metadata.name,
                        bundleId: metadata.bundleId,
                        version: metadata.version,
                        iconName: "app.badge.fill",
                        daysRemaining: 7
                    )
                    
                    Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                        self.statusMessage = "Installata con successo!"
                        self.installedApps.append(newApp)
                        self.isInstalling = false
                        self.installationProgress = 1.0
                    }
                    
                case .failure(let error):
                    self.isInstalling = false
                    if let parserError = error as? IPAParserError {
                        switch parserError {
                        case .invalidArchive: self.errorMessage = "Il file non è un archivio valido (Zip corrotto)."
                        case .infoPlistMissing: self.errorMessage = "Info.plist non trovato. L'IPA potrebbe essere malformata."
                        case .plistReadError: self.errorMessage = "Errore durante la lettura dei metadati dell'app."
                        default: self.errorMessage = "Errore sconosciuto nel parsing."
                        }
                    } else {
                        self.errorMessage = "Errore di sistema: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func refreshAll() {
        // Simulazione refresh firme
        for i in 0..<installedApps.count {
            installedApps[i].daysRemaining = 7
        }
    }
    
    func deleteApp(at offsets: IndexSet) {
        installedApps.remove(atOffsets: offsets)
    }
}
