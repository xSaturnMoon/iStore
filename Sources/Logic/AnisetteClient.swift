import Foundation

// Struttura dei dati Anisette che il server ci restituisce
struct AnisetteData: Codable {
    let X_Apple_I_MD: String
    let X_Apple_I_MD_M: String
    let X_Apple_I_MD_LU: String
    let X_Apple_I_MD_RINFO: String
    let X_Apple_I_SRL_NO: String
    
    // Chiavi alternative (alcuni server usano nomi diversi)
    enum CodingKeys: String, CodingKey {
        case X_Apple_I_MD        = "X-Apple-I-MD"
        case X_Apple_I_MD_M      = "X-Apple-I-MD-M"
        case X_Apple_I_MD_LU     = "X-Apple-I-MD-LU"
        case X_Apple_I_MD_RINFO  = "X-Apple-I-MD-RINFO"
        case X_Apple_I_SRL_NO    = "X-Apple-I-SRL-NO"
    }
    
    // Fallback con valori mock se il server non risponde
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

class AnisetteClient {
    static func fetchHeaders(from urlString: String) async throws -> AnisetteData {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            // Prova a usare valori mock come fallback
            return .mock
        }
        
        // Il server potrebbe rispondere con chiavi in formato diverso
        // Proviamo a decodificare direttamente
        if let anisette = try? JSONDecoder().decode(AnisetteData.self, from: data) {
            return anisette
        }
        
        // Alcuni server restituiscono chiavi senza trattini
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
