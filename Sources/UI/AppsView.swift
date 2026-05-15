import SwiftUI

struct AppsView: View {
    @ObservedObject var manager = AppManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                if manager.installedApps.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 70))
                            .foregroundStyle(.secondary)
                        
                        Text("Nessuna app installata")
                            .font(.title3.bold())
                        
                        Text("Sposta i tuoi file IPA in iStore per iniziare.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(manager.installedApps) { app in
                            AppCard(app: app)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: manager.deleteApp)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Le mie App")
        }
    }
}

struct AppCard: View {
    let app: AppItem
    
    var body: some View {
        HStack(spacing: 15) {
            // App Icon Placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.gradient)
                    .frame(width: 60, height: 60)
                
                Text(String(app.name.prefix(1)).uppercased())
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.headline)
                
                Text(app.bundleId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(app.daysRemaining)gg")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(app.daysRemaining < 3 ? .red.opacity(0.2) : .green.opacity(0.2))
                    .foregroundStyle(app.daysRemaining < 3 ? .red : .green)
                    .clipShape(Capsule())
                
                Text(app.version)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 4)
    }
}
