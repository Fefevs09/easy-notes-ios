import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - PDF Export Error

public enum PDFExportError: LocalizedError, Equatable {
    case documentUnavailable
    case contextCreationFailed
    case invalidPageRange

    public var errorDescription: String? {
        switch self {
        case .documentUnavailable:
            return "O documento PDF da nota não está disponível para exportação."
        case .contextCreationFailed:
            return "Não foi possível criar o contexto de renderização do PDF."
        case .invalidPageRange:
            return "O intervalo de páginas especificado é inválido."
        }
    }
}

// MARK: - PDF Export Options

public struct PDFExportOptions: Equatable, Sendable {
    public var includeGrid: Bool
    public var pageRange: ClosedRange<Int>?
    public var defaultDirectoryURL: URL?

    public static let `default` = PDFExportOptions()

    public init(
        includeGrid: Bool = true,
        pageRange: ClosedRange<Int>? = nil,
        defaultDirectoryURL: URL? = nil
    ) {
        self.includeGrid = includeGrid
        self.pageRange = pageRange
        self.defaultDirectoryURL = defaultDirectoryURL
    }

    /// Parses a 1-based page range string (e.g. "1-3" or "2") and validates it against `pageCount`,
    /// returning a 0-based `ClosedRange<Int>`. Throws `PDFExportError.invalidPageRange` when invalid or out of bounds.
    public static func parsePageRange(_ text: String, pageCount: Int) throws -> ClosedRange<Int> {
        guard pageCount > 0 else {
            throw PDFExportError.invalidPageRange
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PDFExportError.invalidPageRange
        }

        let parts = trimmed.components(separatedBy: "-")
        if parts.count == 1 {
            let part = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let pageNumber = Int(part), pageNumber >= 1, pageNumber <= pageCount else {
                throw PDFExportError.invalidPageRange
            }
            let zeroBased = pageNumber - 1
            return zeroBased...zeroBased
        } else if parts.count == 2 {
            let startPart = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let endPart = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let start = Int(startPart), let end = Int(endPart),
                  start >= 1, end <= pageCount, start <= end else {
                throw PDFExportError.invalidPageRange
            }
            return (start - 1)...(end - 1)
        } else {
            throw PDFExportError.invalidPageRange
        }
    }

    /// Validates a 0-based page range against `pageCount`.
    public static func validate(range: ClosedRange<Int>, pageCount: Int) throws -> ClosedRange<Int> {
        guard pageCount > 0,
              range.lowerBound >= 0,
              range.upperBound < pageCount,
              range.lowerBound <= range.upperBound else {
            throw PDFExportError.invalidPageRange
        }
        return range
    }
}

// MARK: - Save Panel Accessory View

@MainActor
public final class PDFExportAccessoryView: NSView {
    public let pageCount: Int
    public let gridCheckbox: NSButton
    public let allPagesRadio: NSButton
    public let rangeRadio: NSButton
    public let fromLabel: NSTextField
    public let fromField: NSTextField
    public let toLabel: NSTextField
    public let toField: NSTextField

    public init(pageCount: Int, initialIncludeGrid: Bool = true) {
        self.pageCount = pageCount

        self.gridCheckbox = NSButton(checkboxWithTitle: "Incluir grade / estilo de papel", target: nil, action: nil)
        self.gridCheckbox.state = initialIncludeGrid ? .on : .off
        self.gridCheckbox.setAccessibilityLabel("Incluir grade / estilo de papel")

        let pagesCountText = pageCount == 1 ? "Todas (1 página)" : "Todas (\(pageCount) páginas)"
        self.allPagesRadio = NSButton(radioButtonWithTitle: pagesCountText, target: nil, action: nil)
        self.allPagesRadio.state = .on
        self.allPagesRadio.setAccessibilityLabel("Todas as páginas")

        self.rangeRadio = NSButton(radioButtonWithTitle: "Intervalo:", target: nil, action: nil)
        self.rangeRadio.state = .off
        self.rangeRadio.setAccessibilityLabel("Intervalo de páginas")

        self.fromLabel = NSTextField(labelWithString: "De:")
        self.fromLabel.textColor = .disabledControlTextColor
        self.fromField = NSTextField(string: "1")
        self.fromField.isEnabled = false
        self.fromField.alignment = .center
        self.fromField.setAccessibilityLabel("Página inicial")

        self.toLabel = NSTextField(labelWithString: "Até:")
        self.toLabel.textColor = .disabledControlTextColor
        self.toField = NSTextField(string: "\(max(1, pageCount))")
        self.toField.isEnabled = false
        self.toField.alignment = .center
        self.toField.setAccessibilityLabel("Página final")

        super.init(frame: NSRect(x: 0, y: 0, width: 480, height: pageCount > 1 ? 84 : 40))

        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        allPagesRadio.target = self
        allPagesRadio.action = #selector(allPagesClicked)
        rangeRadio.target = self
        rangeRadio.action = #selector(rangeRadioClicked)

        fromField.widthAnchor.constraint(equalToConstant: 44).isActive = true
        toField.widthAnchor.constraint(equalToConstant: 44).isActive = true

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 8
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        rootStack.addArrangedSubview(gridCheckbox)

        if pageCount > 1 {
            let pagesLabel = NSTextField(labelWithString: "Páginas:")
            pagesLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)

            let pagesRow = NSStackView()
            pagesRow.orientation = .horizontal
            pagesRow.alignment = .centerY
            pagesRow.spacing = 12

            let rangeInputsStack = NSStackView(views: [rangeRadio, fromLabel, fromField, toLabel, toField])
            rangeInputsStack.orientation = .horizontal
            rangeInputsStack.alignment = .centerY
            rangeInputsStack.spacing = 6

            pagesRow.addArrangedSubview(pagesLabel)
            pagesRow.addArrangedSubview(allPagesRadio)
            pagesRow.addArrangedSubview(rangeInputsStack)

            rootStack.addArrangedSubview(pagesRow)
        }

        addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            rootStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    @objc private func allPagesClicked() {
        allPagesRadio.state = .on
        rangeRadio.state = .off
        updateControlsState()
    }

    @objc private func rangeRadioClicked() {
        allPagesRadio.state = .off
        rangeRadio.state = .on
        updateControlsState()
    }

    public func updateControlsState() {
        let isRange = (rangeRadio.state == .on)
        fromField.isEnabled = isRange
        toField.isEnabled = isRange
        fromLabel.textColor = isRange ? .labelColor : .disabledControlTextColor
        toLabel.textColor = isRange ? .labelColor : .disabledControlTextColor
        if isRange, let window = window {
            window.makeFirstResponder(fromField)
        }
    }

    public func resolveOptions(defaultDirectoryURL: URL? = nil) throws -> PDFExportOptions {
        let includeGrid = (gridCheckbox.state == .on)
        if pageCount <= 1 || allPagesRadio.state == .on {
            return PDFExportOptions(
                includeGrid: includeGrid,
                pageRange: nil,
                defaultDirectoryURL: defaultDirectoryURL
            )
        }

        let range = try PDFExportOptions.parsePageRange(
            "\(fromField.stringValue)-\(toField.stringValue)",
            pageCount: pageCount
        )
        return PDFExportOptions(
            includeGrid: includeGrid,
            pageRange: range,
            defaultDirectoryURL: defaultDirectoryURL
        )
    }
}

// MARK: - PDF Export Service

@MainActor
public final class PDFExportService {
    public static let shared = PDFExportService()

    public init() {}

    public func exportPDF(
        for note: Note,
        viewModel: NoteViewModel,
        options: PDFExportOptions = .default,
        hostWindow: NSWindow? = nil,
        onError: ((Error) -> Void)? = nil,
        onCompletion: ((URL?) -> Void)? = nil
    ) {
        viewModel.flushTitleEdits()

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = note.suggestedPDFName
        if let dir = options.defaultDirectoryURL {
            savePanel.directoryURL = dir
        }

        let doc = viewModel.getPDFDocument(for: note)
        let pageCount = max(1, doc?.pageCount ?? Int(note.pageCount))

        let accessory = PDFExportAccessoryView(
            pageCount: pageCount,
            initialIncludeGrid: options.includeGrid
        )
        savePanel.accessoryView = accessory

        let completionHandler: (NSApplication.ModalResponse) -> Void = { [weak viewModel] response in
            var exportedURL: URL?
            defer {
                onCompletion?(exportedURL)
            }
            guard response == .OK, let url = savePanel.url, let viewModel = viewModel else {
                return
            }

            do {
                let resolvedOptions = try accessory.resolveOptions(defaultDirectoryURL: options.defaultDirectoryURL)
                try viewModel.exportPDF(for: note, to: url, options: resolvedOptions)
                exportedURL = url
            } catch {
                if let onError = onError {
                    onError(error)
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Falha ao exportar PDF"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }

        let targetWindow = hostWindow ?? NSApp.mainWindow ?? NSApp.keyWindow
        if let window = targetWindow {
            savePanel.beginSheetModal(for: window, completionHandler: completionHandler)
        } else {
            savePanel.begin(completionHandler: completionHandler)
        }
    }
}
