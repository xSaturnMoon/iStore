import Foundation

class GrandSlamAuth {
    // Usiamo la stessa sessione rilassata definita per bypassare errori TLS/SSL locali
    private static let session = URLSession(configuration: .default, delegate: NetworkDelegate(), delegateQueue: nil)
    
    static func authenticate(
        appleId: String,
        password: String,
        anisetteData: AnisetteData,
        anisetteBaseURL: String
    ) async throws -> AppleSession {
        
        let baseURL = anisetteBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        guard let url = URL(string: "\(baseURL)/auth") else {
            throw GrandSlamError.networkError("URL proxy non valido")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "appleId": appleId,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response): (Data, URLResponse)
        do {
            // Usiamo la sessione con delegate per ignorare errori TLS
            (data, response) = try await session.data(for: request)
        } catch {
            throw GrandSlamError.proxyUnreachable
        }
        
        guard let http = response as? HTTPURLResponse else {
            throw GrandSlamError.networkError("Nessuna risposta dal proxy")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GrandSlamError.networkError("Risposta non valida dal proxy")
        }
        
        switch http.statusCode {
        case 200:
            guard let token = json["token"] as? String else {
                throw GrandSlamError.networkError("Token mancante nella risposta")
            }
            return AppleSession(
                appleId: appleId,
                token: token,
                expiry: Date().addingTimeInterval(TimeInterval(json["expiresIn"] as? Int ?? 604800))
            )
            
        case 202:
            let ticket = json["ticket"] as? String ?? UUID().uuidString
            throw GrandSlamError.twoFactorRequired(ticket: ticket)
            
        case 401:
            throw GrandSlamError.invalidCredentials
            
        default:
            let errorMsg = json["error"] as? String ?? "Errore sconosciuto"
            throw GrandSlamError.serverError(http.statusCode, errorMsg)
        }
    }
    
    static func verify2FA(
        code: String,
        sessionId: String,
        anisetteData: AnisetteData,
        anisetteBaseURL: String
    ) async throws -> AppleSession {
        
        let baseURL = anisetteBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        guard let url = URL(string: "\(baseURL)/auth/2fa") else {
            throw GrandSlamError.networkError("URL 2FA non valido")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        
        let body: [String: Any] = ["code": code, "ticket": sessionId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GrandSlamError.proxyUnreachable
        }
        
        guard let http = response as? HTTPURLResponse else {
            throw GrandSlamError.networkError("Nessuna risposta")
        }
        
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        
        if http.statusCode == 200, let token = json["token"] as? String {
            return AppleSession(appleId: "", token: token, expiry: Date().addingTimeInterval(604800))
        }
        
        let errorMsg = json["error"] as? String ?? "Codice 2FA non valido"
        throw GrandSlamError.serverError(http.statusCode, errorMsg)
    }
}
