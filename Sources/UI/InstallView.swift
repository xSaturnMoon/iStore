import SwiftUI

struct InstallView: View {
    @ObservedObject var manager = AppManager.shared
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                if manager.isInstalling {
                    VStack(spacing: 20) {
                        ProgressView(value: manager.installationProgress)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                        
                        Text(manager.statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    // Upload Area
                    Button {
                        showingFilePicker = true
                    } label: {
                        VStack(spacing: 15) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue.gradient)
                            
                            Text("Seleziona file .ipa")
                                .font(.headline)
                            
                            Text("Tocca per sfogliare i tuoi file")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .strokeBorder(.blue.opacity(0.3), lineWidth: 2)
                        )
                    }
                    
                    if let error = manager.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Installa")
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker { url in
                    manager.beginInstall(at: url)
                }
            }
            .alert("Sicurezza", isPresented: $manager.showSecurityAlert) {
                Button("Annulla", role: .cancel) { manager.isInstalling = false }
                Button("Installa comunque", role: .destructive) {
                    manager.proceedWithInstall()
                }
            } message: {
                if let report = manager.securityReport {
                    Text(report.isSafe ? "L'app sembra sicura." : "Attenzione: rilevati potenziali rischi.")
                }
            }
        }
    }
}

// MARK: - Document Picker Wrapper
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.init(filenameExtension: "ipa")!])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}
