import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // SEZIONE APPS
            NavigationStack {
                ZStack {
                    // Sfondo di sistema Apple
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    // Contenuto scorrevole per attivare l'effetto vetro nativo
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(1...15, id: \.self) { index in
                                HStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue.opacity(0.5))
                                        .frame(width: 60, height: 60)
                                    
                                    VStack(alignment: .leading) {
                                        Text("App \(index)")
                                            .font(.headline)
                                        Text("Pronta per l'installazione")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Apri") {}
                                        .buttonStyle(.borderedProminent)
                                        .tint(.blue)
                                        .clipShape(Capsule())
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(16)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .navigationTitle("Apps")
            }
            .tabItem {
                Label("Apps", systemImage: "square.grid.2x2.fill")
            }
            
            // SEZIONE INSTALL
            NavigationStack {
                ZStack {
                    Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                    Text("Trascina qui un file .ipa")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Install")
            }
            .tabItem {
                Label("Install", systemImage: "plus.circle.fill")
            }
            
            // SEZIONE SETTINGS
            NavigationStack {
                ZStack {
                    Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                    Text("Impostazioni Server Anisette")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
    }
}

#Preview {
    ContentView()
}
