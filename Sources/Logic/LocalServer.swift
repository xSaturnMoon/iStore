import Foundation
import Swifter

class LocalServer {
    static let shared = LocalServer()
    private let server = HttpServer()
    private var isRunning = false
    
    private let port: in_port_t = 8080
    
    init() {
        setupRoutes()
    }
    
    private func setupRoutes() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Serviamo tutti i file presenti nella cartella Documents
        // In questo modo, possiamo servire sia il file .ipa che il manifest.plist
        server["/:path"] = shareFilesFromDirectory(documentsURL.path)
    }
    
    func start() {
        guard !isRunning else { return }
        do {
            try server.start(port, forceIPv4: true)
            isRunning = true
            print("Local HTTP Server started on port \(try server.port())")
        } catch {
            print("Failed to start local server: \(error)")
        }
    }
    
    func stop() {
        guard isRunning else { return }
        server.stop()
        isRunning = false
        print("Local HTTP Server stopped.")
    }
    
    /// Crea il file manifest.plist necessario per l'installazione OTA via itms-services.
    func generateManifest(for ipaName: String, bundleId: String, appName: String, version: String) -> URL? {
        let manifestString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>items</key>
            <array>
                <dict>
                    <key>assets</key>
                    <array>
                        <dict>
                            <key>kind</key>
                            <string>software-package</string>
                            <key>url</key>
                            <string>http://127.0.0.1:\(port)/\(ipaName)</string>
                        </dict>
                    </array>
                    <key>metadata</key>
                    <dict>
                        <key>bundle-identifier</key>
                        <string>\(bundleId)</string>
                        <key>bundle-version</key>
                        <string>\(version)</string>
                        <key>kind</key>
                        <string>software</string>
                        <key>title</key>
                        <string>\(appName)</string>
                    </dict>
                </dict>
            </array>
        </dict>
        </plist>
        """
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let manifestURL = documentsURL.appendingPathComponent("manifest.plist")
        
        do {
            try manifestString.write(to: manifestURL, atomically: true, encoding: .utf8)
            return manifestURL
        } catch {
            print("Errore creazione manifest: \(error)")
            return nil
        }
    }
}
