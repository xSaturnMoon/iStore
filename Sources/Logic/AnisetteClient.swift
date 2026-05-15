import Foundation

// MARK: - Sessione "Relaxed" per saltare i controlli TLS/SSL
class NetworkDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Accetta tutto, utile per bypassare errori TLS su reti locali o proxy
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

class AnisetteClient {
    private static let session = URLSession(configuration: .default, delegate: NetworkDelegate(), delegateQueue: nil)

    static func fetchHeaders(from urlString: String) async throws -> AnisetteData {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        // Usiamo la sessione rilassata
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return .mock
        }
        
        if let anisette = try? JSONDecoder().decode(AnisetteData.self, from: data) {
            return anisette
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            return AnisetteData(
                X_Apple_I_MD:       json["X-Apple-I-MD"]       ?? json["adi_pb"]      ?? "AAAA",
                X_Apple_I_MD_M:     json["X-Apple-I-MD-M"]     ?? json["machine_id"]  ?? "AAAA",
                X_Apple_I_MD_LU:    json["X-Apple-I-MD-LU"]    ?? UUID().uuidString,
                X_Apple_I_MD_RINFO: json["X-Apple-I-MD-RINFO"] ?? "17106176",
                X_Apple_I_SRL_NO:   json["X-Apple-I-SRL-NO"]   ?? "0"
            )
        }
        
        return .mock
    }
}

struct AnisetteData: Codable {
    let X_Apple_I_MD: String
    let X_Apple_I_MD_M: String
    let X_Apple_I_MD_LU: String
    let X_Apple_I_MD_RINFO: String
    let X_Apple_I_SRL_NO: String
    
    enum CodingKeys: String, CodingKey {
        case X_Apple_I_MD        = "X-Apple-I-MD"
        case X_Apple_I_MD_M      = "X-Apple-I-MD-M"
        case X_Apple_I_MD_LU     = "X-Apple-I-MD-LU"
        case X_Apple_I_MD_RINFO  = "X-Apple-I-MD-RINFO"
        case X_Apple_I_SRL_NO    = "X-Apple-I-SRL-NO"
    }
    
    static var mock: AnisetteData {
        AnisetteData(
            X_Apple_I_MD: "AAAA",
            X_Apple_I_MD_M: "AAAA",
            X_Apple_I_MD_LU: UUID().uuidString.uppercased(),
            X_Apple_I_MD_RINFO: "17106176",
            X_Apple_I_SRL_NO: "0"
        )
    }
}
