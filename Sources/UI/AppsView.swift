import SwiftUI

struct AppsView: View {
    @ObservedObject var manager: AppManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Statistiche
                HStack(spacing: 15) {
                    StatusCard(title: "Attive", value: "\(manager.installedApps.count)", icon: "checkmark.circle.fill", color: .green)
                    StatusCard(title: "In Scadenza", value: "\(manager.installedApps.filter { $0.daysRemaining <= 2 }.count)", icon: "exclamationmark.triangle.fill", color: .orange)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Lista App
                VStack(alignment: .leading, spacing: 10) {
                    Text("Le mie Applicazioni")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .padding(.horizontal)
                    
                    ForEach(manager.installedApps) { app in
                        AppCard(app: app)
                            .contextMenu {
                                Button(role: .destructive) {
                                    if let index = manager.installedApps.firstIndex(where: { $0.id == app.id }) {
                                        manager.deleteApp(at: IndexSet([index]))
                                    }
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                                
                                Button {
                                    // Refresh singola app
                                } label: {
                                    Label("Rinfresca Firma", systemImage: "arrow.clockwise")
                                }
                            }
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }
}

struct AppCard: View {
    let app: AppItem
    
    var body: some View {
        HStack(spacing: 15) {
            // Icona App
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                
                Image(systemName: app.iconName)
                    .font(.system(size: 30))
                    .foregroundStyle(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.headline)
                Text(app.bundleId)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Indicatore giorni rimanenti
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(app.daysRemaining)d")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(app.daysRemaining <= 2 ? .red : .primary)
                
                Capsule()
                    .fill(app.daysRemaining <= 2 ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                    .frame(width: 40, height: 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.6))
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal)
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}
