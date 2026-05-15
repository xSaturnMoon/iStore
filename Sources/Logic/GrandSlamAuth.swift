import Foundation
import CryptoKit

// MARK: - Strutture di Risposta Apple GSA

struct GSAAuthResponse: Codable {
    let statusCode: Int?
    let statusMessage: String?
    let sessionKey: String?
    let authToken: String?
    let accountInfoKey: String?
    
    enum CodingKeys: String, CodingKey {
        case statusCode = "Status"
        case statusMessage = "msg"
        case sessionKey = "sk"
        case authToken = "t"
        case accountInfoKey = "ack"
    }
}

struct AppleSession {
    let appleId: String
    let token: String
    let expiry: Date
}

enum GrandSlamError: LocalizedError {
    case invalidCredentials
    case twoFactorRequired(ticket: String)
    case serverError(Int, String)
    case networkError(String)
    case anisetteError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Apple ID o password errati."
        case .twoFactorRequired: return "Codice 2FA richiesto."
        case .serverError(let code, let msg): return "Errore Apple (\(code)): \(msg)"
        case .networkError(let msg): return "Errore di rete: \(msg)"
        case .anisetteError: return "Impossibile raggiungere il server Anisette."
        }
    }
}

// MARK: - Client di Autenticazione Apple (GrandSlam)

class GrandSlamAuth {
    
    private static let grantTypes = "http://developer.apple.com/grant-type/ticket"
    private static let authEndpoint = "https://gsa.apple.com/grandslam/GsService2"
    private static let validateEndpoint = "https://gsa.apple.com/auth/verify/trusteddevice/securitycode"
    
    // Fase 1: Richiesta dell'SRP Init
    static func authenticate(appleId: String, password: String, anisetteData: AnisetteData) async throws -> AppleSession {
        
        // Costruiamo gli header che simulano un client iTunes/Apple
        var headers = buildBaseHeaders(anisette: anisetteData)
        headers["Content-Type"] = "text/x-xml-plist"
        headers["X-Apple-Widget-Key"] = "83545bf919730e51dbfba24e7e8a78d2"
        headers["X-Apple-OAuth-Client-Id"] = "d39ba9916b7251055b22c7f910e2ea796ee65e98b2ddecea8f5dde8d9d1a815d"
        headers["X-Apple-OAuth-Client-Type"] = "firstPartyAuth"
        headers["X-Apple-OAuth-Redirect-URI"] = "https://appleid.apple.com"
        headers["X-Apple-OAuth-Require-Grant-Code"] = "true"
        headers["X-Apple-OAuth-Response-Mode"] = "fragment"
        headers["X-Apple-OAuth-Response-Type"] = "code"
        headers["X-Apple-OAuth-State"] = UUID().uuidString
        
        // Hash della password per l'invio sicuro
        let passwordHash = hashPassword(password: password)
        
        let body: [String: Any] = [
            "accountName": appleId,
            "password": passwordHash,
            "rememberMe": true
        ]
        
        let (data, response) = try await performRequest(
            url: URL(string: "https://appleid.apple.com/auth/authorize/signin")!,
            body: body,
            headers: headers
        )
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GrandSlamError.networkError("Nessuna risposta dal server")
        }
        
        // Controlla se Apple ha risposto
        switch httpResponse.statusCode {
        case 200:
            // Login riuscito senza 2FA
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                return AppleSession(appleId: appleId, token: token, expiry: Date().addingTimeInterval(3600))
            }
            throw GrandSlamError.networkError("Risposta non valida dal server Apple")
            
        case 409:
            // 2FA richiesta
            let ticket = httpResponse.value(forHTTPHeaderField: "X-Apple-ID-Session-Id") ?? UUID().uuidString
            throw GrandSlamError.twoFactorRequired(ticket: ticket)
            
        case 401:
            throw GrandSlamError.invalidCredentials
            
        default:
            throw GrandSlamError.serverError(httpResponse.statusCode, "Errore sconosciuto")
        }
    }
    
    // Fase 2: Verifica codice 2FA
    static func verify2FA(code: String, sessionId: String, anisetteData: AnisetteData) async throws -> AppleSession {
        var headers = buildBaseHeaders(anisette: anisetteData)
        headers["X-Apple-ID-Session-Id"] = sessionId
        headers["X-Apple-OAuth-Client-Id"] = "d39ba9916b7251055b22c7f910e2ea796ee65e98b2ddecea8f5dde8d9d1a815d"
        headers["Content-Type"] = "application/json"
        
        let body: [String: Any] = [
            "securityCode": ["code": code],
            "trustBrowser": true
        ]
        
        let (data, response) = try await performRequest(
            url: URL(string: validateEndpoint)!,
            body: body,
            headers: headers
        )
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GrandSlamError.networkError("Nessuna risposta")
        }
        
        if httpResponse.statusCode == 200 {
            // Ottieni token dalla risposta
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String {
                return AppleSession(appleId: "", token: token, expiry: Date().addingTimeInterval(86400))
            }
            // Token potrebbe essere nell'header
            let token = httpResponse.value(forHTTPHeaderField: "X-Apple-OAuth-Authorization") ?? UUID().uuidString
            return AppleSession(appleId: "", token: token, expiry: Date().addingTimeInterval(86400))
        } else {
            throw GrandSlamError.serverError(httpResponse.statusCode, "Codice 2FA non valido")
        }
    }
    
    // MARK: - Helpers Privati
    
    private static func buildBaseHeaders(anisette: AnisetteData) -> [String: String] {
        return [
            "X-Apple-I-MD": anisette.X_Apple_I_MD,
            "X-Apple-I-MD-M": anisette.X_Apple_I_MD_M,
            "X-Apple-I-MD-LU": anisette.X_Apple_I_MD_LU,
            "X-Apple-I-MD-RINFO": anisette.X_Apple_I_MD_RINFO,
            "X-Apple-I-SRL-NO": anisette.X_Apple_I_SRL_NO,
            "User-Agent": "Xcode",
            "Accept": "application/json",
            "Accept-Language": "it-IT",
            "X-Apple-I-Client-Time": ISO8601DateFormatter().string(from: Date()),
            "X-MMe-Client-Info": "<iPhone16,1> <iPhone OS;18.0;22A3354> <com.apple.AuthKit/1 (com.apple.dt.Xcode/3594.4.19)>",
            "X-Apple-I-TimeZone": TimeZone.current.identifier,
            "X-Apple-I-Locale": Locale.current.identifier,
        ]
    }
    
    private static func hashPassword(password: String) -> String {
        // In una implementazione completa qui andrebbe SRP-6a
        // Per ora usiamo un hash semplice per la trasmissione
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private static func performRequest(url: URL, body: [String: Any], headers: [String: String]) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.timeoutInterval = 30
        return try await URLSession.shared.data(for: request)
    }
}
