import PDFKit
import SwiftUI

struct ThumbnailBarView: View {
    @ObservedObject var noteVM: NoteViewModel
    let pdfDocument: PDFDocument?
    @Binding var selectedPageIndex: Int

    var body: some View {
        let pageCount = pdfDocument?.pageCount ?? 0

        VStack(spacing: 0) {
            HStack {
                Text("PÁGINAS")
                    .studioSectionHeader()

                Spacer()

                Button {
                    noteVM.addBlankPage()
                } label: {
                    Image(systemName: "plus")
                        .font(PixelTheme.uiFont(size: 12, weight: .semibold))
                        .foregroundStyle(PixelTheme.accent)
                        .frame(width: 24, height: 24)
                        .background(PixelTheme.accentSoft, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Adicionar página em branco")
                .help("Adicionar página em branco")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            if let page = pdfDocument?.page(at: index), let note = noteVM.selectedNote {
                                Button {
                                    selectedPageIndex = index
                                } label: {
                                    PageThumbnail(note: note, page: page, number: index + 1, isSelected: selectedPageIndex == index)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Página \(index + 1)")
                                .accessibilityAddTraits(selectedPageIndex == index ? .isSelected : [])
                                .id(index)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                }
                .onAppear {
                    proxy.scrollTo(selectedPageIndex)
                }
                .onChange(of: selectedPageIndex) { _, index in
                    proxy.scrollTo(index)
                }
            }

            Rectangle()
                .fill(PixelTheme.border)
                .frame(height: 1)

            Text("\(pageCount) \(pageCount == 1 ? "página" : "páginas")")
                .font(PixelTheme.uiFont(size: 11))
                .foregroundStyle(PixelTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PixelTheme.surface)
    }
}

struct PageThumbnail: View {
    @ObservedObject var note: Note
    let page: PDFPage
    let number: Int
    let isSelected: Bool
    @State private var thumbnailImage: NSImage?

    private struct ThumbnailRevision: Equatable {
        let updatedAt: Date
        let imageIDs: Set<UUID>
        let textBlockTimestamps: [UUID: Date]
    }

    var body: some View {
        let outline = RoundedRectangle(cornerRadius: 6)

        VStack(spacing: 5) {
            Group {
                if let thumbnailImage {
                    Image(nsImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(PixelTheme.paper)
                }
            }
            .frame(width: 112, height: 148)
            .background(PixelTheme.paper)
            .clipShape(outline)
            .overlay {
                outline.strokeBorder(
                    isSelected ? PixelTheme.accent : PixelTheme.border,
                    lineWidth: isSelected ? 2 : 1
                )
            }
            .shadow(color: PixelTheme.ink.opacity(0.08), radius: 4, y: 2)
            .accessibilityHidden(true)

            Text("\(number)")
                .font(PixelTheme.uiFont(size: 11, weight: isSelected ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(isSelected ? PixelTheme.paper : PixelTheme.muted)
                .padding(.horizontal, 9)
                .frame(height: 20)
                .background {
                    if isSelected {
                        Capsule().fill(PixelTheme.accent)
                    }
                }
        }
        .contentShape(Rectangle())
        .task(id: ThumbnailRevision(
            updatedAt: note.updatedAt,
            imageIDs: Set((note.editorImages as? Set<EditorImage> ?? [])
                .filter { Int($0.pageIndex) == number - 1 }.map(\.id)),
            textBlockTimestamps: Dictionary(
                note.textBlocksArray
                    .filter { Int($0.pageIndex) == number - 1 }
                    .map { ($0.id, $0.updatedAt) },
                uniquingKeysWith: { max($0, $1) }
            )
        )) {
            thumbnailImage = Self.renderThumbnail(for: page, note: note, pageIndex: number - 1)
        }
        .id(ObjectIdentifier(page))
    }

    static func renderThumbnail(for page: PDFPage, note: Note, pageIndex: Int) -> NSImage {
        let mediaBox = page.bounds(for: .mediaBox)
        guard mediaBox.width > 0, mediaBox.height > 0 else { return NSImage() }
        let paper = page.thumbnail(of: CGSize(width: 224, height: 296), for: .mediaBox)
        let size = paper.size
        guard size.width >= 1, size.height >= 1 else { return paper }

        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let graphics = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let context = graphics.cgContext
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.saveGState()
        paper.draw(in: CGRect(origin: .zero, size: size))
        let transform = page.transform(for: .mediaBox)
        let displayBounds = mediaBox.applying(transform)
        context.scaleBy(x: size.width / displayBounds.width, y: size.height / displayBounds.height)
        context.translateBy(x: -displayBounds.minX, y: -displayBounds.minY)
        context.concatenate(transform)
        renderGrid(for: note, in: mediaBox, into: context)
        renderEditorImages(for: note, pageIndex: pageIndex, into: context)
        renderPageDrawings(for: note, pageIndex: pageIndex, mediaBox: mediaBox, into: context)
        renderTextBlocks(for: note, pageIndex: pageIndex, into: context)
        context.restoreGState()
        NSGraphicsContext.restoreGraphicsState()
        let output = NSImage(size: size)
        output.addRepresentation(rep)
        return output
    }
}
