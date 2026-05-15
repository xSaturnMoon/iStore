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
    
    init() {
        // Inizialmente vuoto, caricherai tu le tue app vere
        installedApps = []
    }
    
    func installIPA(at url: URL) {
        isInstalling = true
        installationProgress = 0.1
        
        // Eseguiamo il parsing in background per non bloccare la UI
        DispatchQueue.global(qos: .userInitiated).async {
            if let metadata = IPAParser.parse(at: url) {
                DispatchQueue.main.async {
                    self.installationProgress = 0.5
                    
                    // Qui aggiungiamo l'app reale alla lista
                    let newApp = AppItem(
                        name: metadata.name,
                        bundleId: metadata.bundleId,
                        version: metadata.version,
                        iconName: "app.badge.fill", // In futuro estrarremo anche l'icona
                        daysRemaining: 7
                    )
                    
                    // Simuliamo la fine dell'installazione
                    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                        self.installedApps.append(newApp)
                        self.isInstalling = false
                        self.installationProgress = 1.0
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    // Qui potremmo mostrare un errore
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
