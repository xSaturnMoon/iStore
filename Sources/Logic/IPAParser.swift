import Foundation
import ZIPFoundation

struct IPAMetadata {
    let name: String
    let bundleId: String
    let version: String
}

class IPAParser {
    static func parse(at url: URL) -> IPAMetadata? {
        let fileManager = FileManager.default
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true)
            
            // Unzip solo l'Info.plist per essere veloci
            let archive = try Archive(url: url, accessMode: .read)
            
            guard let entry = archive.first(where: { $0.path.contains("Info.plist") && $0.path.contains("Payload/") }) else {
                return nil
            }
            
            let plistURL = tempURL.appendingPathComponent("Info.plist")
            _ = try archive.extract(entry, to: plistURL)
            
            // Leggi il file Plist
            let data = try Data(contentsOf: plistURL)
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                let name = plist["CFBundleDisplayName"] as? String ?? plist["CFBundleName"] as? String ?? "App Sconosciuta"
                let bundleId = plist["CFBundleIdentifier"] as? String ?? "unknown.bundle"
                let version = plist["CFBundleShortVersionString"] as? String ?? "1.0"
                
                // Pulizia
                try? fileManager.removeItem(at: tempURL)
                
                return IPAMetadata(name: name, bundleId: bundleId, version: version)
            }
        } catch {
            print("Errore durante il parsing dell'IPA: \(error)")
        }
        
        return nil
    }
}
