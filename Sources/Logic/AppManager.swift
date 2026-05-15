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
        statusMessage = "Apertura file IPA..."
        installationProgress = 0.1
        
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { self.statusMessage = "Analisi metadati..." }
            
            if let metadata = IPAParser.parse(at: url) {
                DispatchQueue.main.async {
                    self.statusMessage = "Preparazione installazione..."
                    self.installationProgress = 0.5
                    
                    let newApp = AppItem(
                        name: metadata.name,
                        bundleId: metadata.bundleId,
                        version: metadata.version,
                        iconName: "app.badge.fill",
                        daysRemaining: 7
                    )
                    
                    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                        self.statusMessage = "Completato!"
                        self.installedApps.append(newApp)
                        self.isInstalling = false
                        self.installationProgress = 1.0
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.errorMessage = "Impossibile leggere il file IPA. Assicurati che sia un file valido."
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
