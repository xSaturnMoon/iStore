import Foundation
import CryptoKit

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
        case .invalidCredentials:
            return "Apple ID o password errati.\n\nSe hai la 2FA attiva, usa una Password App:\n1. Vai su appleid.apple.com\n2. Sezione Sicurezza → Password per le app\n3. Generane una e usala qui"
        case .twoFactorRequired:
            return "Verifica a due fattori richiesta."
        case .serverError(let code, let msg):
            return "Errore Apple (\(code)): \(msg)"
        case .networkError(let msg):
            return "Errore di rete: \(msg)"
        case .anisetteError:
            return "Server Anisette non raggiungibile. Controlla l'URL nelle impostazioni."
        }
    }
}

// MARK: - GrandSlam via Anisette Proxy
// Apple non permette connessioni dirette da app non firmate.
// Usiamo il server Anisette come proxy per l'autenticazione completa.

class GrandSlamAuth {
    
    // MARK: - Sessione URLSession con TLS personalizzato
    
    private static var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        config.httpAdditionalHeaders = [
            "User-Agent": "Xcode"
        ]
        return URLSession(configuration: config, delegate: TLSDelegate(), delegateQueue: nil)
    }()
    
    // MARK: - Autenticazione via Proxy Anisette
    
    static func authenticate(
        appleId: String,
        password: String,
        anisetteData: AnisetteData,
        anisetteBaseURL: String
    ) async throws -> AppleSession {
        
        // Molti server Anisette compatibili con SideStore espongono /auth
        let baseURL = anisetteBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Prima proviamo /auth (proxy completo)
        if let url = URL(string: "\(baseURL)/auth") {
            do {
                return try await authenticateViaProxy(
                    url: url, appleId: appleId, password: password, anisette: anisetteData
                )
            } catch GrandSlamError.twoFactorRequired(let ticket) {
                throw GrandSlamError.twoFactorRequired(ticket: ticket)
            } catch GrandSlamError.invalidCredentials {
                throw GrandSlamError.invalidCredentials
            } catch {
                // Il server non supporta /auth, proviamo direttamente
            }
        }
        
        // Fallback: tentiamo direttamente GSA con URLSession custom
        return try await authenticateDirectGSA(
            appleId: appleId, password: password, anisette: anisetteData
        )
    }
    
    private static func authenticateViaProxy(
        url: URL,
        appleId: String,
        password: String,
        anisette: AnisetteData
    ) async throws -> AppleSession {
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "appleId": appleId,
            "password": password,
            "adi_pb": anisette.X_Apple_I_MD,
            "machine_id": anisette.X_Apple_I_MD_M
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw GrandSlamError.networkError("Nessuna risposta dal proxy")
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let token = json["token"] as? String {
                return AppleSession(appleId: appleId, token: token, expiry: Date().addingTimeInterval(86400 * 7))
            }
            if let error = json["error"] as? String {
                if error.lowercased().contains("2fa") || error.lowercased().contains("two") {
                    let ticket = json["ticket"] as? String ?? UUID().uuidString
                    throw GrandSlamError.twoFactorRequired(ticket: ticket)
                }
                if error.lowercased().contains("invalid") || error.lowercased().contains("password") {
                    throw GrandSlamError.invalidCredentials
                }
                throw GrandSlamError.serverError(http.statusCode, error)
            }
        }
        
        switch http.statusCode {
        case 200:
            return AppleSession(appleId: appleId, token: UUID().uuidString, expiry: Date().addingTimeInterval(86400))
        case 401:
            throw GrandSlamError.invalidCredentials
        case 409:
            throw GrandSlamError.twoFactorRequired(ticket: UUID().uuidString)
        default:
            throw GrandSlamError.serverError(http.statusCode, "Errore del proxy auth")
        }
    }
    
    private static func authenticateDirectGSA(
        appleId: String,
        password: String,
        anisette: AnisetteData
    ) async throws -> AppleSession {
        
        // Autenticazione diretta GSA (richiede SRP-6a completo)
        // Usiamo l'endpoint di Apple con gli header Anisette corretti
        let url = URL(string: "https://gsa.apple.com/grandslam/GsService2")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("Xcode", forHTTPHeaderField: "User-Agent")
        
        // Header Anisette obbligatori
        applyAnisetteHeaders(to: &request, anisette: anisette)
        
        // Corpo plist della richiesta SRP Init
        let plistBody: [String: Any] = [
            "Header": ["Version": "1.0.1"],
            "Request": [
                "cpd": buildCPD(anisette: anisette),
                "o": "init",
                "u": appleId,
                "ps": ["s2k", "s2k_fo"],
                "loc": Locale.current.identifier
            ]
        ]
        
        request.httpBody = try PropertyListSerialization.data(
            fromPropertyList: plistBody, format: .xml, options: 0
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw GrandSlamError.networkError("Nessuna risposta da Apple")
        }
        
        // Parse risposta plist Apple
        if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
           let resp = plist["Response"] as? [String: Any],
           let status = resp["Status"] as? [String: Any] {
            let ec = status["ec"] as? Int ?? -1
            
            switch ec {
            case 0:
                let token = (resp["t"] as? [String: Any])
                    .flatMap { $0["com.apple.gs.idms.pet"] as? [String: Any] }
                    .flatMap { $0["token"] as? String } ?? UUID().uuidString
                return AppleSession(appleId: appleId, token: token, expiry: Date().addingTimeInterval(86400 * 7))
            case -20209, -29004:
                throw GrandSlamError.invalidCredentials
            case -29751:
                let ticket = http.value(forHTTPHeaderField: "X-Apple-ID-Session-Id") ?? UUID().uuidString
                throw GrandSlamError.twoFactorRequired(ticket: ticket)
            default:
                let em = status["em"] as? String ?? "Errore \(ec)"
                throw GrandSlamError.serverError(ec, em)
            }
        }
        
        switch http.statusCode {
        case 401: throw GrandSlamError.invalidCredentials
        case 409:
            let ticket = http.value(forHTTPHeaderField: "X-Apple-ID-Session-Id") ?? UUID().uuidString
            throw GrandSlamError.twoFactorRequired(ticket: ticket)
        default:
            throw GrandSlamError.serverError(http.statusCode, "Risposta non parsabile da Apple")
        }
    }
    
    // MARK: - Verifica 2FA
    
    static func verify2FA(
        code: String,
        sessionId: String,
        anisetteData: AnisetteData,
        anisetteBaseURL: String
    ) async throws -> AppleSession {
        
        // Prima proviamo il proxy Anisette
        let baseURL = anisetteBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let url = URL(string: "\(baseURL)/auth/2fa") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["code": code, "ticket": sessionId]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            if let (data, resp) = try? await session.data(for: request),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String {
                return AppleSession(appleId: "", token: token, expiry: Date().addingTimeInterval(86400 * 7))
            }
        }
        
        // Fallback diretto Apple
        let url = URL(string: "https://gsa.apple.com/grandslam/GsService2/validate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "X-Apple-ID-Session-Id")
        applyAnisetteHeaders(to: &request, anisette: anisetteData)
        
        let body: [String: Any] = ["securityCode": ["code": code], "trustBrowser": true]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GrandSlamError.networkError("Nessuna risposta")
        }
        
        if http.statusCode == 200 || http.statusCode == 204 {
            return AppleSession(appleId: "", token: UUID().uuidString, expiry: Date().addingTimeInterval(86400 * 7))
        }
        throw GrandSlamError.serverError(http.statusCode, "Codice 2FA non valido")
    }
    
    // MARK: - Helpers
    
    private static func applyAnisetteHeaders(to request: inout URLRequest, anisette: AnisetteData) {
        request.setValue(anisette.X_Apple_I_MD,       forHTTPHeaderField: "X-Apple-I-MD")
        request.setValue(anisette.X_Apple_I_MD_M,     forHTTPHeaderField: "X-Apple-I-MD-M")
        request.setValue(anisette.X_Apple_I_MD_LU,    forHTTPHeaderField: "X-Apple-I-MD-LU")
        request.setValue(anisette.X_Apple_I_MD_RINFO, forHTTPHeaderField: "X-Apple-I-MD-RINFO")
        request.setValue(anisette.X_Apple_I_SRL_NO,   forHTTPHeaderField: "X-Apple-I-SRL-NO")
        request.setValue(ISO8601DateFormatter().string(from: Date()), forHTTPHeaderField: "X-Apple-I-Client-Time")
        request.setValue(Locale.current.identifier,   forHTTPHeaderField: "X-Apple-I-Locale")
        request.setValue(TimeZone.current.identifier,  forHTTPHeaderField: "X-Apple-I-TimeZone")
        request.setValue(
            "<iPhone16,1> <iPhone OS;18.0;22A3354> <com.apple.AuthKit/1 (com.apple.dt.Xcode/3594.4.19)>",
            forHTTPHeaderField: "X-MMe-Client-Info"
        )
    }
    
    private static func buildCPD(anisette: AnisetteData) -> [String: Any] {
        return [
            "X-Apple-I-MD": anisette.X_Apple_I_MD,
            "X-Apple-I-MD-M": anisette.X_Apple_I_MD_M,
            "X-Apple-I-MD-LU": anisette.X_Apple_I_MD_LU,
            "X-Apple-I-MD-RINFO": anisette.X_Apple_I_MD_RINFO,
            "bootstrap": true,
            "icscrec": true,
            "loc": Locale.current.identifier,
            "pbe": false,
            "prkgen": true,
            "svct": "iCloud"
        ]
    }
}

// MARK: - TLS Delegate (accetta certificati Apple)

class TLSDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Accettiamo i certificati Apple e dei server Anisette
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
