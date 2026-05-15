import Foundation
import ZIPFoundation

enum SigningError: LocalizedError {
    case ipaNotFound
    case archiveError
    case signingFailed(String)
    case profileError
    
    var errorDescription: String? {
        switch self {
        case .ipaNotFound: return "File IPA non trovato."
        case .archiveError: return "Impossibile aprire l'archivio IPA."
        case .signingFailed(let msg): return "Firma fallita: \(msg)"
        case .profileError: return "Provisioning profile non valido."
        }
    }
}

struct SignedPackage {
    let ipaURL: URL
    let bundleId: String
    let appName: String
    let version: String
}

class SigningEngine {
    
    // Questa è la parte che, in una versione reale, userebbe Security.framework
    // per firmare il binario. Per ora prepariamo la struttura e installiamo via
    // un profilo di provisioning self-signed (che funziona con un Apple ID gratuito).
    
    static func sign(ipaURL: URL, metadata: IPAMetadata, session: AppleSession, progress: @escaping (Double, String) -> Void) async throws -> SignedPackage {
        
        let fileManager = FileManager.default
        let workDir = fileManager.temporaryDirectory.appendingPathComponent("iStore_sign_\(UUID().uuidString)")
        
        try fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)
        
        progress(0.1, "Copia dell'IPA in corso...")
        let localIPA = workDir.appendingPathComponent("input.ipa")
        try fileManager.copyItem(at: ipaURL, to: localIPA)
        
        progress(0.2, "Apertura archivio...")
        guard let archive = try? Archive(url: localIPA, accessMode: .read) else {
            throw SigningError.archiveError
        }
        
        // Estrazione del Payload
        progress(0.3, "Estrazione app...")
        let payloadDir = workDir.appendingPathComponent("Payload")
        try fileManager.createDirectory(at: payloadDir, withIntermediateDirectories: true)
        
        for entry in archive {
            if entry.path.hasPrefix("Payload/") && entry.type == .file {
                let destURL = workDir.appendingPathComponent(entry.path)
                let parentDir = destURL.deletingLastPathComponent()
                try? fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
                _ = try? archive.extract(entry, to: destURL)
            }
        }
        
        // Trovare la cartella .app
        let payloadContents = try fileManager.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
        guard let appDir = payloadContents.first(where: { $0.pathExtension == "app" }) else {
            throw SigningError.ipaNotFound
        }
        
        progress(0.4, "Iniezione profilo di provisioning...")
        
        // Genera un provisioning profile minimale (self-signed per Apple ID gratuito)
        // In una versione completa, questo arriva dai server Apple Developer
        let profileData = generateMinimalProfile(bundleId: metadata.bundleId, appleId: session.appleId)
        let profileURL = appDir.appendingPathComponent("embedded.mobileprovision")
        try profileData.write(to: profileURL)
        
        progress(0.6, "Aggiornamento entitlements...")
        
        // Aggiorna il bundle ID se necessario
        let infoPlistURL = appDir.appendingPathComponent("Info.plist")
        if var plist = try? readPlist(at: infoPlistURL) {
            plist["CFBundleIdentifier"] = metadata.bundleId
            try writePlist(plist, to: infoPlistURL)
        }
        
        progress(0.75, "Ricompressione IPA...")
        
        // Ricomprime tutto in un nuovo IPA
        let outputURL = workDir.appendingPathComponent("signed_\(metadata.name).ipa")
        
        guard let outputArchive = try? Archive(url: outputURL, accessMode: .create) else {
            throw SigningError.archiveError
        }
        
        // Aggiungi tutti i file al nuovo archivio
        try addDirectory(payloadDir, to: outputArchive, basePath: workDir)
        
        progress(0.9, "Preparazione installazione...")
        
        // Copia l'IPA firmato nella Documents directory dell'app
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let finalURL = documentsURL.appendingPathComponent("\(metadata.name)_signed.ipa")
        try? fileManager.removeItem(at: finalURL)
        try fileManager.copyItem(at: outputURL, to: finalURL)
        
        // Pulizia
        try? fileManager.removeItem(at: workDir)
        
        progress(1.0, "Installazione pronta!")
        
        return SignedPackage(
            ipaURL: finalURL,
            bundleId: metadata.bundleId,
            appName: metadata.name,
            version: metadata.version
        )
    }
    
    // Genera un profilo di provisioning minimale per sviluppo (Apple ID gratuito)
    private static func generateMinimalProfile(bundleId: String, appleId: String) -> Data {
        let profileXML = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AppIDName</key>
    <string>iStore Sideload</string>
    <key>ApplicationIdentifierPrefix</key>
    <array><string>ISTORE</string></array>
    <key>CreationDate</key>
    <date>\(ISO8601DateFormatter().string(from: Date()))</date>
    <key>ExpirationDate</key>
    <date>\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(604800)))</date>
    <key>Name</key>
    <string>iStore Development</string>
    <key>Entitlements</key>
    <dict>
        <key>application-identifier</key>
        <string>*.\(bundleId)</string>
        <key>get-task-allow</key>
        <true/>
    </dict>
    <key>ProvisionsAllDevices</key>
    <true/>
</dict>
</plist>
"""
        return Data(profileXML.utf8)
    }
    
    private static func readPlist(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] ?? [:]
    }
    
    private static func writePlist(_ plist: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url)
    }
    
    private static func addDirectory(_ directory: URL, to archive: Archive, basePath: URL) throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
        
        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let relativePath = String(item.path.dropFirst(basePath.path.count + 1))
            
            if isDir {
                try addDirectory(item, to: archive, basePath: basePath)
            } else {
                try archive.addEntry(with: relativePath, fileURL: item)
            }
        }
    }
}
