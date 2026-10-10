import PhotosUI
import SwiftUI

/// What a verified student shares about a pickup (student.md "Past Surprise Reveals and feedback").
struct RevealFeedback {
    var overall = 5
    var portion = 4
    var surprise = 4
    var pickup = 5
    var again = true
    var comment = ""
    var photoJPEG: Data?
}

/// Rate a verified pickup and optionally share a photo as a Past Reveal.
struct RevealFeedbackView: View {
    let rescue: StudentRescue
    let onSubmit: (RevealFeedback) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var feedback = RevealFeedback()
    @State private var photoItem: PhotosPickerItem?
    @State private var photoPreview: UIImage?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        BrandMark(brand: rescue.brand, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rescue.business)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            Text("\(ImpactFormat.shortDate(rescue.verifiedAt)) · verified pickup")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(KnightTheme.muted)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("How was it?") {
                    StarRow(title: "Overall", value: $feedback.overall, large: true)
                    StarRow(title: "Portion", value: $feedback.portion)
                    StarRow(title: "Surprise quality", value: $feedback.surprise)
                    StarRow(title: "Pickup experience", value: $feedback.pickup)
                    Toggle("Would you reserve again?", isOn: $feedback.again)
                        .tint(KnightTheme.green)
                }

                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        if let photoPreview {
                            Image(uiImage: photoPreview)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            Label("Add a photo of what you got", systemImage: "camera")
                        }
                    }
                    TextField("Say something about it (optional)", text: $feedback.comment, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Share your reveal")
                } footer: {
                    Text("Your photo and comment can appear as a Past Reveal on this business. Past Reveals show earlier experiences and never promise future contents.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(KnightTheme.paper)
            .navigationTitle("Rate your pickup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Send") {
                        onSubmit(feedback)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                    feedback.photoJPEG = EcoKnightClient.preparedJPEG(from: data)
                    photoPreview = feedback.photoJPEG.flatMap(UIImage.init(data:))
                }
            }
        }
        .tint(KnightTheme.ink)
    }
}

private struct StarRow: View {
    let title: String
    @Binding var value: Int
    var large = false

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: large ? 17 : 15, weight: large ? .semibold : .regular))
            Spacer()
            HStack(spacing: large ? 6 : 4) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        value = star
                    } label: {
                        Image(systemName: star <= value ? "star.fill" : "star")
                            .font(.system(size: large ? 22 : 16))
                            .foregroundStyle(KnightTheme.goldDeep)
                            .frame(width: large ? 30 : 24, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title), \(value) of 5")
    }
}
