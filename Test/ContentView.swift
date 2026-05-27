import SwiftUI

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Count: \(count)")
                .font(.title)
            Button("Increment") {
                count += 1
            }
        }
        .padding()
        .frame(width: 200, height: 120)
    }
}

#Preview {
    ContentView()
}
