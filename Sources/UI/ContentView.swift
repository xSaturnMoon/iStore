import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 1
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // SFONDO GRIGIO APPLE
            Color(UIColor.systemGray6)
                .ignoresSafeArea()
            
            // COLOR BLOBS (Per far risaltare il vetro)
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 300)
                .blur(radius: 70)
                .offset(x: -150, y: 100)
            
            Circle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 300)
                .blur(radius: 70)
                .offset(x: 150, y: 300)
            
            // CONTENUTO PRINCIPALE
            VStack {
                Spacer()
                Text(tabName(for: selectedTab))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // TAB BAR FLUTTUANTE (GLASS UFFICIALE)
            HStack(spacing: 40) {
                TabButton(icon: "plus.circle.fill", label: "Install", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                TabButton(icon: "square.grid.2x2.fill", label: "Apps", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                
                TabButton(icon: "gearshape.fill", label: "Settings", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 25)
            // --- EFFETTO VETRO APPLE ---
            .background(.ultraThinMaterial, in: Capsule())
            // ---------------------------
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            .padding(.bottom, 20) // La facciamo fluttuare
        }
    }
    
    func tabName(for index: Int) -> String {
        switch index {
        case 0: return "Install"
        case 1: return "Apps"
        case 2: return "Settings"
        default: return ""
        }
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? .blue : .primary.opacity(0.6))
            .frame(width: 50)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
