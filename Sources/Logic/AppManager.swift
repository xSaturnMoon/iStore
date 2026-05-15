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
        // Dati di esempio per testare il design
        loadSampleData()
    }
    
    func loadSampleData() {
        installedApps = [
            AppItem(name: "iStore", bundleId: "com.xsaturnmoon.istore", version: "1.0", iconName: "shippingbox.fill", daysRemaining: 7, isSystemApp: true),
            AppItem(name: "WhatsApp+", bundleId: "com.whatsapp.plus", version: "2.23", iconName: "message.fill", daysRemaining: 5),
            AppItem(name: "YouTube Reborn", bundleId: "com.google.ios.youtube", version: "18.10", iconName: "play.rectangle.fill", daysRemaining: 3),
            AppItem(name: "Instagram Rocket", bundleId: "com.burbn.instagram", version: "280.0", iconName: "camera.fill", daysRemaining: 1)
        ]
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
