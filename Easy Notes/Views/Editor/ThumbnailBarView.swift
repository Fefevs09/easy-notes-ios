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
                            if let page = pdfDocument?.page(at: index) {
                                Button {
                                    selectedPageIndex = index
                                } label: {
                                    PageThumbnail(page: page, number: index + 1, isSelected: selectedPageIndex == index)
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

private struct PageThumbnail: View {
    let page: PDFPage
    let number: Int
    let isSelected: Bool
    @State private var thumbnailImage: NSImage?

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
        .task(id: ObjectIdentifier(page)) {
            thumbnailImage = page.thumbnail(of: CGSize(width: 224, height: 296), for: .mediaBox)
        }
    }
}
