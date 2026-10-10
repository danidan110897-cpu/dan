import SwiftUI
import SwiftData
import PhotosUI

struct ProgressPhotosView: View {
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var profile
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]
    @State private var picked: PhotosPickerItem?
    @State private var selected: ProgressPhoto?
    @State private var showCompare = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        ScrollView {
            if photos.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 44)).foregroundStyle(Theme.accent)
                    Text("Nessuna foto").font(.headline)
                    Text("Aggiungi una foto ogni 2-4 settimane, sempre con la stessa luce e posa. Restano solo sul tuo telefono.")
                        .font(.footnote).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)
                }
                .padding(40)
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(photos) { photo in
                    Button { selected = photo } label: {
                        ZStack(alignment: .bottomLeading) {
                            if let image = PhotoStorage.image(photo.filename) {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(minHeight: 140).frame(maxWidth: .infinity).clipped()
                            } else {
                                Color.gray.opacity(0.2).frame(height: 140)
                            }
                            Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2.weight(.semibold)).padding(4)
                                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6)).padding(4)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Foto progressi")
        .toolbar {
            if photos.count >= 2 {
                ToolbarItem(placement: .topBarLeading) { Button("Confronta") { showCompare = true } }
            }
            ToolbarItem(placement: .topBarTrailing) {
                PhotosPicker(selection: $picked, matching: .images) { Image(systemName: "plus") }
            }
        }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let name = PhotoStorage.save(data) {
                    context.insert(ProgressPhoto(date: .now, filename: name, weightKg: profile.profile.weightKg))
                }
                picked = nil
            }
        }
        .sheet(item: $selected) { PhotoDetail(photo: $0) }
        .sheet(isPresented: $showCompare) { CompareView(photos: photos.sorted { $0.date < $1.date }) }
    }
}

private struct PhotoDetail: View {
    let photo: ProgressPhoto
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileStore.self) private var profile
    @State private var analyzing = false
    @State private var error: String?
    @State private var notes: [String] = []
    @State private var confirmSend = false

    var body: some View {
        NavigationStack {
            VStack {
                if let image = PhotoStorage.image(photo.filename) {
                    Image(uiImage: image).resizable().scaledToFit()
                }
                if let w = photo.weightKg {
                    Text("\(photo.date.formatted(date: .long, time: .omitted)) · \(formatWeight(w)) kg")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                estimateSection
            }
            .padding()
            .confirmationDialog("Inviare la foto per la stima?", isPresented: $confirmSend, titleVisibility: .visible) {
                Button("Invia e stima") { runEstimate() }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("La foto viene inviata a \(ClaudeClient.providerName) con la tua chiave API per essere analizzata.\(ClaudeClient.privacyNote) Leggi le loro condizioni sulla privacy prima di procedere.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Elimina", systemImage: "trash", role: .destructive) {
                        PhotoStorage.delete(photo.filename)
                        context.delete(photo)
                        dismiss()
                    }
                }
            }
        }
    }
}

extension PhotoDetail {
    @ViewBuilder
    fileprivate var estimateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let low = photo.estimateLow, let high = photo.estimateHigh {
                Label("Stima AI: \(Int(low.rounded()))–\(Int(high.rounded()))% di grasso corporeo", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                if let c = photo.estimateConfidence {
                    Text("Affidabilità: \(c == "high" ? "alta" : c == "medium" ? "media" : "bassa")")
                        .font(.caption).foregroundStyle(Theme.secondaryText)
                }
                ForEach(notes, id: \.self) { Text($0).font(.caption).foregroundStyle(Theme.secondaryText) }
            }
            if profile.profile.age < 18 {
                Text("La stima dalla foto è disponibile solo per maggiorenni.").font(.caption).foregroundStyle(Theme.secondaryText)
            } else if !ClaudeClient.hasKey {
                Text("Per la stima dalla foto inserisci una chiave API in Impostazioni (quella gratuita di Google Gemini va bene).")
                    .font(.caption).foregroundStyle(Theme.secondaryText)
            } else {
                Button { confirmSend = true } label: {
                    HStack { if analyzing { ProgressView() }; Text(photo.estimateLow == nil ? "Stima il grasso dalla foto" : "Stima di nuovo") }
                }
                .buttonStyle(.bordered).disabled(analyzing)
            }
            if let error { Text(error).font(.caption).foregroundStyle(Theme.move) }
            Text("È una stima con un margine di errore di diversi punti percentuali (luce, posa e pelle cambiano il risultato). Non è una misura medica: usala solo per confrontare nel tempo, al massimo una volta ogni 1-2 settimane. Se il rapporto con il tuo corpo o il cibo ti crea disagio, parlane con un professionista.")
                .font(.caption2).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    fileprivate func runEstimate() {
        analyzing = true
        error = nil
        let file = photo.filename
        let p = profile.profile
        Task {
            do {
                let result = try await PhotoAnalyzer.estimate(photoFile: file, profile: p)
                photo.estimateLow = result.low
                photo.estimateHigh = result.high
                photo.estimateConfidence = result.confidence
                notes = result.notes
            } catch {
                self.error = error.localizedDescription
            }
            analyzing = false
        }
    }
}

/// Before/after slider: drag the handle to reveal one photo over the other.
private struct CompareView: View {
    let photos: [ProgressPhoto]
    @Environment(\.dismiss) private var dismiss
    @State private var beforeIndex = 0
    @State private var afterIndex: Int
    @State private var split: CGFloat = 0.5

    init(photos: [ProgressPhoto]) {
        self.photos = photos
        _afterIndex = State(initialValue: max(photos.count - 1, 0))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                GeometryReader { geo in
                    ZStack {
                        photoView(afterIndex).frame(width: geo.size.width, height: geo.size.height)
                        photoView(beforeIndex)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .mask(alignment: .leading) {
                                Rectangle().frame(width: geo.size.width * split)
                            }
                        Rectangle().fill(.white).frame(width: 3)
                            .overlay(Circle().fill(.white).frame(width: 32).overlay(Image(systemName: "arrow.left.and.right").foregroundStyle(.black)))
                            .position(x: geo.size.width * split, y: geo.size.height / 2)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { split = min(max($0.location.x / geo.size.width, 0), 1) })
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack {
                    picker("Prima", $beforeIndex)
                    Spacer()
                    picker("Dopo", $afterIndex)
                }
            }
            .padding()
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Confronto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fine") { dismiss() } }
        }
    }

    private func photoView(_ index: Int) -> some View {
        Group {
            if photos.indices.contains(index), let image = PhotoStorage.image(photos[index].filename) {
                Image(uiImage: image).resizable().scaledToFill().clipped()
            } else {
                Color.gray.opacity(0.2)
            }
        }
    }

    private func picker(_ title: String, _ selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(photos.indices, id: \.self) { i in
                Text(photos[i].date.formatted(date: .abbreviated, time: .omitted)).tag(i)
            }
        }
        .pickerStyle(.menu)
    }
}
