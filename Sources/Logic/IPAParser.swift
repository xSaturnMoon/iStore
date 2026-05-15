import Foundation
import ZIPFoundation

struct IPAMetadata {
    let name: String
    let bundleId: String
    let version: String
}

enum IPAParserError: Error {
    case fileNotFound
    case invalidArchive
    case infoPlistMissing
    case plistReadError
}

class IPAParser {
    static func parse(at url: URL) -> Result<IPAMetadata, Error> {
        let fileManager = FileManager.default
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let localIpaURL = tempURL.appendingPathComponent("temp.ipa")
        
        do {
            try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true)
            
            // Copiamo l'IPA localmente per evitare problemi di permessi sandbox
            try fileManager.copyItem(at: url, to: localIpaURL)
            
            guard let archive = try? Archive(url: localIpaURL, accessMode: .read) else {
                return .failure(IPAParserError.invalidArchive)
            }
            
            // Cerchiamo l'Info.plist in modo più elastico
            // Deve essere dentro Payload/ e dentro una cartella .app/
            let entries = archive.filter { entry in
                let path = entry.path.lowercased()
                return path.contains("payload/") && 
                       path.contains(".app/") && 
                       path.hasSuffix("info.plist") &&
                       !path.contains("frameworks/") // Evitiamo Info.plist dei framework interni
            }
            
            guard let entry = entries.first else {
                return .failure(IPAParserError.infoPlistMissing)
            }
            
            let plistURL = tempURL.appendingPathComponent("extracted_info.plist")
            _ = try archive.extract(entry, to: plistURL)
            
            let data = try Data(contentsOf: plistURL)
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                let name = plist["CFBundleDisplayName"] as? String ?? 
                           plist["CFBundleName"] as? String ?? 
                           plist["CFBundleExecutable"] as? String ?? "App Sconosciuta"
                
                let bundleId = plist["CFBundleIdentifier"] as? String ?? "unknown.bundle"
                let version = plist["CFBundleShortVersionString"] as? String ?? 
                              plist["CFBundleVersion"] as? String ?? "1.0"
                
                // Pulizia
                try? fileManager.removeItem(at: tempURL)
                
                return .success(IPAMetadata(name: name, bundleId: bundleId, version: version))
            } else {
                return .failure(IPAParserError.plistReadError)
            }
        } catch {
            return .failure(error)
        }
    }
}
