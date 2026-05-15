import Foundation

class AnisetteClient {
    private static let session = URLSession(configuration: .default, delegate: NetworkDelegate(), delegateQueue: nil)

    static func fetchHeaders(from urlString: String) async throws -> AnisetteData {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
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
