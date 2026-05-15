import SwiftUI

struct ContentView: View {
    @State private var selectedSection: String = "Apps"
    
    var body: some View {
        ZStack {
            // Sfondo Grigio Apple (System Gray)
            Color(UIColor.systemGray6)
                .ignoresSafeArea()
            
            HStack(spacing: 0) {
                // SIDEBAR GLASS
                VStack(alignment: .leading, spacing: 20) {
                    Text("iStore")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .padding(.bottom, 30)
                        .foregroundStyle(.primary)
                    
                    SidebarButton(title: "Install", icon: "plus.circle.fill", isSelected: selectedSection == "Install") {
                        selectedSection = "Install"
                    }
                    
                    SidebarButton(title: "Apps", icon: "square.grid.2x2.fill", isSelected: selectedSection == "Apps") {
                        selectedSection = "Apps"
                    }
                    
                    SidebarButton(title: "Settings", icon: "gearshape.fill", isSelected: selectedSection == "Settings") {
                        selectedSection = "Settings"
                    }
                    
                    Spacer()
                }
                .padding(.top, 50)
                .padding(.horizontal, 20)
                .frame(width: 250)
                // --- EFFETTO VETRO UFFICIALE ---
                .background(.ultraThinMaterial)
                // ------------------------------
                
                // Area Contenuto Principale
                VStack {
                    Spacer()
                    Text(selectedSection)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 18, weight: .medium))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .foregroundStyle(isSelected ? .blue : .primary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
