import AppKit
import CoreData
import SwiftUI

struct EditorAnnotationsSidebar: View {
    @ObservedObject var note: Note
    let selectedPageIndex: Int

    private struct Annotation: Identifiable {
        let id: NSManagedObjectID
        let title: String
        let colorHex: String
        let createdAt: Date
    }

    var body: some View {
        let annotations = pageAnnotations
        let pageAnnotationCount = annotations.count

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Anotações")
                    .font(PixelTheme.displayFont(size: 15, weight: .bold))
                    .foregroundStyle(PixelTheme.ink)

                Text("\(pageAnnotationCount)")
                    .font(PixelTheme.uiFont(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(PixelTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PixelTheme.accentSoft, in: Capsule())
                    .accessibilityLabel("\(pageAnnotationCount) anotações nesta página")
            }

            Text("NESTA PÁGINA")
                .studioSectionHeader()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if annotations.isEmpty {
                        Text("Nenhuma anotação nesta página")
                            .font(PixelTheme.uiFont(size: 12))
                            .foregroundStyle(PixelTheme.muted)
                    } else {
                        ForEach(annotations) { annotation in
                            annotationCard(annotation)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
            .padding(.horizontal, -14)
            .frame(maxHeight: .infinity)

            preservationCard
        }
        .padding(14)
    }

    private var pageAnnotations: [Annotation] {
        // Persisted strokes have no tool identifier, so all freehand strokes share a label.
        let strokes = note.strokesArray
            .filter { Int($0.pageIndex) == selectedPageIndex }
            .map { Annotation(id: $0.objectID, title: "Escrita à mão", colorHex: $0.color, createdAt: $0.createdAt) }
        let shapes = note.shapesArray
            .filter { Int($0.pageIndex) == selectedPageIndex }
            .map {
                Annotation(
                    id: $0.objectID,
                    title: ShapeKind(rawValue: $0.kind)?.displayName ?? "Forma",
                    colorHex: $0.strokeColor,
                    createdAt: $0.createdAt
                )
            }
        return (strokes + shapes).sorted { $0.createdAt > $1.createdAt }
    }

    private func annotationCard(_ annotation: Annotation) -> some View {
        let color = NSColor(hex: annotation.colorHex).map { Color(nsColor: $0) } ?? PixelTheme.inkCharcoal

        return HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(annotation.title)
                    .font(PixelTheme.uiFont(size: 12, weight: .semibold))
                    .foregroundStyle(PixelTheme.ink)
                Text(annotation.createdAt.formatted(.dateTime.day().month().hour().minute().locale(Locale(identifier: "pt_BR"))))
                    .font(PixelTheme.uiFont(size: 11))
                    .foregroundStyle(PixelTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .studioCard(radius: 10)
        .accessibilityElement(children: .combine)
    }

    private var preservationCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("PDF original preservado", systemImage: "checkmark")
                .font(PixelTheme.uiFont(size: 12, weight: .semibold))
                .foregroundStyle(PixelTheme.success)
            Text("Suas anotações ficam em uma camada.")
                .font(PixelTheme.uiFont(size: 11))
                .foregroundStyle(PixelTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(PixelTheme.successSoft, in: RoundedRectangle(cornerRadius: 10))
    }
}
