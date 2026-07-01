import SwiftUI
import PDFKit

struct ThumbnailBarView: View {
    @ObservedObject var noteVM: NoteViewModel
    let pdfDocument: PDFDocument?
    @Binding var selectedPageIndex: Int
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Páginas")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    noteVM.addBlankPage()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Adicionar página em branco")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    if let doc = pdfDocument {
                        ForEach(0..<doc.pageCount, id: \.self) { i in
                            if let page = doc.page(at: i) {
                                let thumb = page.thumbnail(of: CGSize(width: 100, height: 140), for: .mediaBox)
                                let isSelected = selectedPageIndex == i
                                
                                VStack(spacing: 4) {
                                    Image(nsImage: thumb)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 90, height: 120)
                                        .background(Color.white)
                                        .cornerRadius(4)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.accentColor, lineWidth: isSelected ? 2.5 : 0)
                                        )
                                    Text("\(i + 1)")
                                        .font(.caption)
                                        .fontWeight(isSelected ? .bold : .regular)
                                        .foregroundColor(isSelected ? .accentColor : .secondary)
                                }
                                .padding(4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedPageIndex = i
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 130)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }
}
