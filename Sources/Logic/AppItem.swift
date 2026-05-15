import Foundation

struct AppItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var bundleId: String
    var version: String
    var iconName: String
    var daysRemaining: Int
    var isSystemApp: Bool
    var signedIpaPath: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        bundleId: String,
        version: String,
        iconName: String,
        daysRemaining: Int,
        isSystemApp: Bool = false,
        signedIpaPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleId = bundleId
        self.version = version
        self.iconName = iconName
        self.daysRemaining = daysRemaining
        self.isSystemApp = isSystemApp
        self.signedIpaPath = signedIpaPath
    }
}
