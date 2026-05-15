import SwiftUI
import UniformTypeIdentifiers

struct InstallView: View {
    @ObservedObject var manager: AppManager
    @State private var showFilePicker = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Area di caricamento animata
            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .foregroundStyle(.blue.opacity(0.3))
                    .frame(width: 250, height: 250)
                
                VStack(spacing: 20) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                        .symbolEffect(.bounce, value: manager.isInstalling)
                    
                    Text("Seleziona File .ipa")
                        .font(.headline)
                    
                    Text("Trascina o scegli un file dalla memoria del tuo iPhone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .onTapGesture {
                showFilePicker = true
            }
            
            if manager.isInstalling {
                VStack(spacing: 10) {
                    ProgressView(value: manager.installationProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                        .padding(.horizontal, 50)
                    
                    Text("Installazione in corso... \(Int(manager.installationProgress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Pulsante Sfoglia
            Button {
                showFilePicker = true
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                    Text("Sfoglia File")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(15)
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 100)
        }
        .fileImporter(
            isPresented: &showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "ipa")!],
            allowsMultipleSelection: false
        ) { result in
            // Qui gestiamo il file selezionato
            manager.isInstalling = true
            simulateInstallation()
        }
    }
    
    func simulateInstallation() {
        manager.installationProgress = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            manager.installationProgress += 0.02
            if manager.installationProgress >= 1.0 {
                timer.invalidate()
                manager.isInstalling = false
                // Aggiungiamo un'app finta al catalogo dopo il test
                manager.installedApps.append(AppItem(name: "New App", bundleId: "com.test.app", version: "1.0", iconName: "app.badge.fill", daysRemaining: 7))
            }
        }
    }
}
