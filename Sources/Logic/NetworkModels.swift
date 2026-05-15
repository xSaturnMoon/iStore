import Foundation

// MARK: - Sessione per l'accesso Apple
struct AppleSession: Codable {
    let appleId: String
    let token: String
    let expiry: Date
}

// MARK: - Dati Anisette
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

// MARK: - Delegato per bypassare controlli SSL su reti locali
class NetworkDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
