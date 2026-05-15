import Foundation
import ZIPFoundation

// MARK: - Security Result

enum SecurityRisk: String {
    case clean
    case warning
    case danger
}

struct SecurityFinding {
    let risk: SecurityRisk
    let title: String
    let description: String
}

struct SecurityReport {
    let overallRisk: SecurityRisk
    let findings: [SecurityFinding]
    
    var isSafe: Bool { overallRisk == .clean }
    var hasDangers: Bool { findings.contains(where: { $0.risk == .danger }) }
    var hasWarnings: Bool { findings.contains(where: { $0.risk == .warning }) }
}

// MARK: - Security Scanner

class SecurityScanner {
    
    // Entitlements considerati pericolosi per il sideloading
    private static let dangerousEntitlements = [
        "com.apple.private.mobileinstall.allowedSPI",
        "com.apple.springboard.debugapplications",
        "com.apple.private.security.no-sandbox",
        "platform-application",
        "com.apple.private.skip-library-validation",
        "get-task-allow"
    ]
    
    // Permessi che richiedono attenzione
    private static let sensitiveKeys = [
        ("NSCameraUsageDescription", "Accesso alla fotocamera"),
        ("NSMicrophoneUsageDescription", "Accesso al microfono"),
        ("NSLocationAlwaysAndWhenInUseUsageDescription", "Posizione GPS sempre attiva"),
        ("NSContactsUsageDescription", "Accesso ai contatti"),
        ("NSFaceIDUsageDescription", "Accesso a Face ID"),
    ]
    
    static func scan(at url: URL) -> SecurityReport {
        let fileManager = FileManager.default
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        var findings: [SecurityFinding] = []
        
        do {
            try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true)
            let localIpa = tempURL.appendingPathComponent("scan.ipa")
            try fileManager.copyItem(at: url, to: localIpa)
            
            guard let archive = try? Archive(url: localIpa, accessMode: .read) else {
                return SecurityReport(overallRisk: .danger, findings: [
                    SecurityFinding(risk: .danger, title: "Archivio non valido", description: "Il file IPA non può essere letto. Potrebbe essere corrotto o manomesso.")
                ])
            }
            
            // 1. Scansione Info.plist per permessi
            if let plistEntry = archive.first(where: {
                $0.path.lowercased().contains("payload/") &&
                $0.path.lowercased().contains(".app/") &&
                $0.path.lowercased().hasSuffix("info.plist") &&
                !$0.path.lowercased().contains("frameworks/")
            }) {
                let plistURL = tempURL.appendingPathComponent("Info.plist")
                _ = try archive.extract(plistEntry, to: plistURL)
                
                if let data = try? Data(contentsOf: plistURL),
                   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                    
                    // Controlla permessi sensibili
                    for (key, label) in sensitiveKeys {
                        if plist[key] != nil {
                            findings.append(SecurityFinding(
                                risk: .warning,
                                title: "Permesso: \(label)",
                                description: "L'app richiede \(label.lowercased()). Verifica che sia necessario."
                            ))
                        }
                    }
                    
                    // Controlla versione minima iOS
                    if let minVersion = plist["MinimumOSVersion"] as? String,
                       let major = Int(minVersion.split(separator: ".").first ?? "0"),
                       major < 14 {
                        findings.append(SecurityFinding(
                            risk: .warning,
                            title: "Versione iOS molto vecchia",
                            description: "L'app supporta iOS \(minVersion)+. App molto vecchie possono avere vulnerabilità note."
                        ))
                    }
                }
            }
            
            // 2. Scansione entitlements embedded
            if let entEntry = archive.first(where: {
                $0.path.lowercased().contains("entitlements")
            }) {
                let entURL = tempURL.appendingPathComponent("entitlements.plist")
                _ = try archive.extract(entEntry, to: entURL)
                
                if let data = try? Data(contentsOf: entURL),
                   let ent = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                    
                    for key in dangerousEntitlements {
                        if ent[key] != nil {
                            findings.append(SecurityFinding(
                                risk: .danger,
                                title: "Entitlement privato Apple",
                                description: "L'app usa '\(key)' — tipico di app jailbreak o malware. Procedi solo se ti fidi della fonte."
                            ))
                        }
                    }
                }
            }
            
            // 3. Controlla la presenza di framework sospetti
            let suspiciousFrameworks = ["Cydia", "Substrate", "CydiaSubstrate", "Frida"]
            for entry in archive {
                for fw in suspiciousFrameworks {
                    if entry.path.contains(fw) {
                        findings.append(SecurityFinding(
                            risk: .danger,
                            title: "Framework sospetto: \(fw)",
                            description: "Rilevato framework '\(fw)'. Questo è tipico di strumenti di hooking o spyware."
                        ))
                    }
                }
            }
            
        } catch {
            findings.append(SecurityFinding(
                risk: .warning,
                title: "Scansione incompleta",
                description: "Errore durante l'analisi: \(error.localizedDescription)"
            ))
        }
        
        try? fileManager.removeItem(at: tempURL)
        
        // Calcola rischio complessivo
        let overallRisk: SecurityRisk
        if findings.contains(where: { $0.risk == .danger }) {
            overallRisk = .danger
        } else if findings.contains(where: { $0.risk == .warning }) {
            overallRisk = .warning
        } else {
            overallRisk = .clean
        }
        
        return SecurityReport(overallRisk: overallRisk, findings: findings)
    }
}
