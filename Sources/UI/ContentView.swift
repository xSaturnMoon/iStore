import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 1
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // SFONDO GRIGIO SCURO (Migliora il contrasto del vetro)
            Color(red: 0.05, green: 0.05, blue: 0.07)
                .ignoresSafeArea()
            
            // COLOR BLOBS ANIMATI (Fondamentali per vedere l'effetto vetro)
            Group {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 400)
                    .blur(radius: 100)
                    .offset(x: -150, y: 100)
                    .opacity(0.4)
                
                Circle()
                    .fill(Color.purple)
                    .frame(width: 400)
                    .blur(radius: 100)
                    .offset(x: 150, y: -100)
                    .opacity(0.4)
            }
            
            // CONTENUTO PRINCIPALE
            VStack {
                Spacer()
                Text(tabName(for: selectedTab))
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .shadow(radius: 10)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // --- TAB BAR "TRUE GLASS" ---
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
            .padding(.vertical, 16)
            .padding(.horizontal, 30)
            // L'effetto segreto: ultraThinMaterial con saturazione forzata
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
            .padding(.bottom, 40)
            // ---------------------------
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
                    .font(.system(size: 24))
                Text(label)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(isSelected ? .blue : .white.opacity(0.5))
            .shadow(color: isSelected ? .blue.opacity(0.5) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
