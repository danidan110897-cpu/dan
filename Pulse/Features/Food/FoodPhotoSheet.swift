import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Take or pick a photo of the meal, let the AI list the foods, correct the grams, then log everything at once.
struct FoodPhotoSheet: View {
    let meal: Meal
    let day: Date
    let onDone: () -> Void

    private struct Row: Identifiable {
        let id = UUID()
        var name: String
        var grams: Double
        var confidence: String
        var resolved: ResolvedFood
        var kcal: Double { resolved.kcal100 * grams / 100 }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("usdaKey") private var usdaKey = "DEMO_KEY"

    enum Method: String, CaseIterable, Identifiable {
        case onDevice = "Sul telefono (gratis)"
        case claude = "Claude (più preciso)"
        var id: String { rawValue }
    }

    @State private var method: Method = .onDevice
    @State private var picked: PhotosPickerItem?
    @State private var showCamera = false
    @State private var imageData: Data?
    @State private var hint = ""
    @State private var confirmSend = false
    @State private var loading = false
    @State private var rows: [Row] = []
    @State private var note = ""
    @State private var error: String?
    @State private var analyzed = false

    private var totalKcal: Double { rows.reduce(0) { $0 + $1.kcal } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if ClaudeClient.hasKey {
                        Picker("Metodo", selection: $method) {
                            ForEach(Method.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    Label(method == .onDevice
                          ? "La foto resta sul telefono. \(AIEngine.appleStatus.isAvailable ? "Uso Apple Intelligence." : "Apple Intelligence non disponibile: riconoscimento di base.")"
                          : "La foto viene inviata ad Anthropic con la tua chiave: stima più precisa di cibi e porzioni.",
                          systemImage: method == .onDevice ? "lock.shield" : "paperplane")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                .listRowBackground(Theme.card)

                Section {
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(height: 220).frame(maxWidth: .infinity).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .listRowInsets(EdgeInsets())
                            .transition(.scale.combined(with: .opacity))
                    }
                    HStack {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button("Scatta", systemImage: "camera.fill") { showCamera = true }
                        }
                        PhotosPicker(selection: $picked, matching: .images) { Label("Libreria", systemImage: "photo") }
                    }
                    .buttonStyle(.bordered)
                    TextField("Aiuta l'AI (es. riso 80 g a crudo, olio 1 cucchiaio)", text: $hint, axis: .vertical)
                        .font(.footnote)
                } footer: {
                    Text("Per una stima migliore: foto dall'alto, luce buona, piatto intero e una posata o la mano vicino come riferimento. Le informazioni che scrivi qui hanno la precedenza.")
                }
                .listRowBackground(Theme.card)

                if imageData != nil {
                    Section {
                        Button { if method == .claude { confirmSend = true } else { analyze() } } label: {
                            HStack { if loading { ProgressView() }; Image(systemName: "sparkles"); Text(analyzed ? "Analizza di nuovo" : "Analizza il piatto") }
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(loading)
                    }
                    .listRowBackground(Color.clear)
                }

                if let error {
                    Text(error).font(.footnote).foregroundStyle(Theme.move).listRowBackground(Color.clear)
                }

                if analyzed {
                    Section("Alimenti riconosciuti") {
                        if rows.isEmpty { Text("Nessun alimento riconosciuto.").foregroundStyle(Theme.secondaryText) }
                        ForEach($rows) { $row in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(row.name).font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(Int(row.kcal)) kcal").font(.subheadline).contentTransition(.numericText())
                                }
                                HStack {
                                    TextField("g", value: $row.grams, format: .number)
                                        .keyboardType(.decimalPad).frame(width: 70)
                                        .padding(6).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                                    Text("g").foregroundStyle(Theme.secondaryText)
                                    Spacer()
                                    Text("\(row.resolved.source) · \(confidenceLabel(row.confidence))")
                                        .font(.caption2).foregroundStyle(Theme.recover)
                                }
                                if let matched = row.resolved.matchedName {
                                    Text(matched).font(.caption2).foregroundStyle(Theme.secondaryText).lineLimit(1)
                                }
                            }
                        }
                        .onDelete { rows.remove(atOffsets: $0) }
                    }
                    .listRowBackground(Theme.card)

                    if !note.isEmpty {
                        Section { Text(note).font(.footnote).foregroundStyle(Theme.secondaryText) }
                            .listRowBackground(Theme.card)
                    }
                    Section {
                        Text("La stima delle porzioni da una foto sbaglia spesso del 15-30%. Controlla e correggi i grammi: è la parte che conta di più.")
                            .font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Foto del piatto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                if analyzed && !rows.isEmpty {
                    Button(action: add) {
                        Text("Aggiungi a \(meal.label) · \(Int(totalKcal)) kcal").font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent).foregroundStyle(.black).padding()
                    .sensoryFeedback(.success, trigger: rows.count)
                }
            }
            .animation(Motion.smooth, value: analyzed)
            .animation(Motion.snappy, value: rows.count)
            .animation(Motion.snappy, value: imageData)
            .onChange(of: picked) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) { setImage(data) }
                    picked = nil
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { data in setImage(data); showCamera = false }.ignoresSafeArea()
            }
            .confirmationDialog("Inviare la foto per l'analisi?", isPresented: $confirmSend, titleVisibility: .visible) {
                Button("Invia e analizza") { analyze() }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("La foto del piatto viene inviata ad Anthropic con la tua chiave API. Leggi le loro condizioni sulla privacy prima di procedere.")
            }
        }
    }

    private func confidenceLabel(_ c: String) -> String {
        c == "high" ? "sicuro" : c == "medium" ? "abbastanza sicuro" : "incerto"
    }

    private func setImage(_ data: Data) {
        guard let image = UIImage(data: data) else { return }
        let scale = min(1, 1024 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let scaled = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        imageData = scaled.jpegData(compressionQuality: 0.8)
        analyzed = false
        rows = []
        error = nil
    }

    private func analyze() {
        guard let imageData else { return }
        loading = true
        error = nil
        let key = usdaKey
        let hintText = hint
        Task {
            do {
                let result = method == .claude
                    ? try await FoodPhotoAnalyzer.analyze(jpeg: imageData, hint: hintText)
                    : try await FoodPhotoAnalyzer.analyzeLocal(jpeg: imageData, hint: hintText)
                var built: [Row] = []
                for item in result.items {
                    let resolved = await FoodPhotoAnalyzer.resolve(item, usdaKey: key)
                    built.append(Row(name: item.name, grams: item.grams, confidence: item.confidence, resolved: resolved))
                }
                rows = built
                note = result.note
                analyzed = true
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private func add() {
        for row in rows where row.grams > 0 {
            let food = FoodResult(key: "photo:\(UUID().uuidString)", name: row.name,
                                  kcal100: row.resolved.kcal100, protein100: row.resolved.protein100,
                                  carbs100: row.resolved.carbs100, fat100: row.resolved.fat100,
                                  source: row.resolved.source)
            FoodLogger.add(food, grams: row.grams, meal: meal, day: day, context: context)
        }
        dismiss()
        onDone()
    }
}

/// Camera capture (system camera UI).
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (Data) -> Void
        init(onImage: @escaping (Data) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) { onImage(data) }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
