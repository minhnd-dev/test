import SwiftUI

struct DictionaryPanelView: View {
    let word: String
    let definitions: [Definition]
    let onAddToAnki: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(word)
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: onAddToAnki) {
                    Label("Add to Anki", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .help("Create an Anki card from this word")
            }

            ForEach(definitions.indices, id: \.self) { index in
                let def = definitions[index]
                HStack(alignment: .top, spacing: 6) {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("(\(def.partOfSpeech))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(def.meaning)
                    }
                }
            }
        }
        .padding()
    }
}
