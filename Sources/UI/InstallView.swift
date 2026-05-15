import SwiftUI
import UniformTypeIdentifiers

struct InstallView: View {
    @ObservedObject var manager: AppManager
    @State private var showFilePicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                
                // MARK: - Upload Area
                uploadArea
                
                // MARK: - Progress
                if manager.isInstalling {
                    installProgressView
                }
                
                Spacer(minLength: 40)
            }
            .padding(.top, 20)
        }
        
        // MARK: - File Picker
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "ipa")!],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                _ = url.startAccessingSecurityScopedResource()
                manager.beginInstall(at: url)
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // MARK: - Security Alert
        .sheet(isPresented: $manager.showSecurityAlert) {
            SecurityAlertSheet(manager: manager)
        }
        
        // MARK: - Error Alert
        .alert("Errore", isPresented: Binding(
            get: { manager.errorMessage != nil },
            set: { _ in manager.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(manager.errorMessage ?? "")
        }
    }
    
    // MARK: - Subviews
    
    private var uploadArea: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [12, 6]))
                    .foregroundStyle(.blue.opacity(0.4))
                    .frame(width: 220, height: 220)
                
                Circle()
                    .fill(.blue.opacity(0.07))
                    .frame(width: 200, height: 200)
                
                VStack(spacing: 16) {
                    Image(systemName: manager.isInstalling ? "gearshape.2.fill" : "arrow.down.doc.fill")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse, isActive: manager.isInstalling)
                    
                    Text(manager.isInstalling ? "Elaborazione..." : "Seleziona .ipa")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
            .onTapGesture {
                if !manager.isInstalling { showFilePicker = true }
            }
            
            Text("Tocca il cerchio o usa il pulsante per\nselezionare un file .ipa dal tuo iPhone")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var installProgressView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                HStack {
                    Text(manager.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(Int(manager.installationProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                
                ProgressView(value: manager.installationProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                    .animation(.easeInOut, value: manager.installationProgress)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}

// MARK: - Security Alert Sheet

struct SecurityAlertSheet: View {
    @ObservedObject var manager: AppManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Icona rischio
                    VStack(spacing: 12) {
                        Image(systemName: riskIcon)
                            .font(.system(size: 52))
                            .foregroundStyle(riskColor)
                        
                        Text(riskTitle)
                            .font(.title2.bold())
                        
                        Text(riskSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 10)
                    
                    // Lista problemi trovati
                    if let report = manager.securityReport {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(report.findings, id: \.title) { finding in
                                SecurityFindingRow(finding: finding)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                    
                    // Pulsanti azione
                    VStack(spacing: 12) {
                        Button {
                            dismiss()
                            manager.showSecurityAlert = false
                            manager.proceedWithInstall()
                        } label: {
                            Label("Procedi comunque", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(riskColor)
                                .cornerRadius(14)
                        }
                        
                        Button(role: .destructive) {
                            dismiss()
                            manager.cancelInstall()
                        } label: {
                            Text("Blocca installazione")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Scansione Sicurezza")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    private var riskIcon: String {
        guard let report = manager.securityReport else { return "checkmark.shield" }
        switch report.overallRisk {
        case .danger: return "xmark.shield.fill"
        case .warning: return "exclamationmark.shield.fill"
        case .clean: return "checkmark.shield.fill"
        }
    }
    
    private var riskColor: Color {
        guard let report = manager.securityReport else { return .green }
        switch report.overallRisk {
        case .danger: return .red
        case .warning: return .orange
        case .clean: return .green
        }
    }
    
    private var riskTitle: String {
        guard let report = manager.securityReport else { return "" }
        switch report.overallRisk {
        case .danger: return "Pericolo Rilevato"
        case .warning: return "Attenzione Richiesta"
        case .clean: return "File Sicuro"
        }
    }
    
    private var riskSubtitle: String {
        guard let report = manager.securityReport else { return "" }
        switch report.overallRisk {
        case .danger: return "Questo IPA contiene elementi tipici di malware o spyware. Ti consigliamo di non installarlo."
        case .warning: return "Questo IPA richiede permessi sensibili. Verifica la fonte prima di procedere."
        case .clean: return "Nessun elemento sospetto trovato."
        }
    }
}

// MARK: - Security Finding Row

struct SecurityFindingRow: View {
    let finding: SecurityFinding
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.system(size: 20))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(finding.title)
                    .font(.subheadline.bold())
                Text(finding.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(iconColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var iconName: String {
        switch finding.risk {
        case .danger: return "xmark.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .clean: return "checkmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch finding.risk {
        case .danger: return .red
        case .warning: return .orange
        case .clean: return .green
        }
    }
}
