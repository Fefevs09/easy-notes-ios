import CoreGraphics
import CoreText
import Foundation

enum NoteTemplate: String, CaseIterable {
    case blank = "Em branco"
    case monthlyCalendar = "Calendário mensal"
    case taskList = "Lista de tarefas"
}

enum NoteTemplateError: LocalizedError {
    case invalidMonth
    case pdfCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidMonth: "Escolha um mês e informe um ano de 1 a 9999."
        case .pdfCreationFailed: "Não foi possível gerar a primeira página da nota."
        }
    }
}

struct MonthlyCalendarLayout {
    let title: String
    let weekdays: [String]
    let firstDayOffset: Int
    let dayCount: Int
    var rowCount: Int { (firstDayOffset + dayCount + 6) / 7 }

    static func calendar(for locale: Locale) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = .gmt
        return calendar
    }

    init(month: Int, year: Int, locale: Locale) throws {
        let calendar = Self.calendar(for: locale)
        guard (1...12).contains(month), (1...9999).contains(year),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let days = calendar.range(of: .day, in: .month, for: date) else {
            throw NoteTemplateError.invalidMonth
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        title = formatter.string(from: date)

        let symbols = calendar.shortStandaloneWeekdaySymbols
        weekdays = (0..<7).map { symbols[($0 + calendar.firstWeekday - 1) % 7] }
        firstDayOffset = (calendar.component(.weekday, from: date) - calendar.firstWeekday + 7) % 7
        dayCount = days.count
    }

    func position(of day: Int) -> (row: Int, column: Int) {
        let index = firstDayOffset + day - 1
        return (index / 7, index % 7)
    }
}

enum NoteTemplatePDF {
    static func make(
        _ template: NoteTemplate, month: Int, year: Int?,
        orientation: NoteOrientation, locale: Locale
    ) throws -> (data: Data, document: CGPDFDocument) {
        let calendar: MonthlyCalendarLayout?
        if template == .monthlyCalendar {
            guard let year else { throw NoteTemplateError.invalidMonth }
            calendar = try MonthlyCalendarLayout(month: month, year: year, locale: locale)
        } else {
            calendar = nil
        }

        let data = NSMutableData()
        var bounds = CGRect(origin: .zero, size: orientation.pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &bounds, nil) else {
            throw NoteTemplateError.pdfCreationFailed
        }

        context.beginPDFPage(nil)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        let content = bounds.insetBy(dx: 36, dy: 36)
        if let calendar {
            drawCalendar(calendar, locale: locale, in: content, into: context)
        } else if template == .taskList {
            drawTasks(in: content, into: context)
        }
        context.endPDFPage()
        context.closePDF()

        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider), document.numberOfPages == 1 else {
            throw NoteTemplateError.pdfCreationFailed
        }
        return (data as Data, document)
    }

    private static func drawCalendar(
        _ calendar: MonthlyCalendarLayout, locale: Locale, in bounds: CGRect, into context: CGContext
    ) {
        drawText(calendar.title, size: 26, at: CGPoint(x: bounds.minX, y: bounds.maxY - 26), into: context)
        let gridTop = bounds.maxY - 84
        let columnWidth = bounds.width / 7
        let rowHeight = (gridTop - bounds.minY) / CGFloat(calendar.rowCount)

        context.setStrokeColor(CGColor(gray: 0.62, alpha: 1))
        context.setLineWidth(0.75)
        for (column, name) in calendar.weekdays.enumerated() {
            let x = bounds.minX + CGFloat(column) * columnWidth
            drawText(name, size: 13, at: CGPoint(x: x + 8, y: gridTop + 9), into: context)
        }
        for column in 0...7 {
            let x = bounds.minX + CGFloat(column) * columnWidth
            context.move(to: CGPoint(x: x, y: gridTop))
            context.addLine(to: CGPoint(x: x, y: bounds.minY))
        }
        for row in 0...calendar.rowCount {
            let y = gridTop - CGFloat(row) * rowHeight
            context.move(to: CGPoint(x: bounds.minX, y: y))
            context.addLine(to: CGPoint(x: bounds.maxX, y: y))
        }
        context.strokePath()

        for day in 1...calendar.dayCount {
            let (row, column) = calendar.position(of: day)
            let x = bounds.minX + CGFloat(column) * columnWidth + 8
            let y = gridTop - CGFloat(row) * rowHeight - 20
            drawText(day.formatted(.number.locale(locale)), size: 13, at: CGPoint(x: x, y: y), into: context)
        }
    }

    private static func drawTasks(in bounds: CGRect, into context: CGContext) {
        drawText(NoteTemplate.taskList.rawValue, size: 26,
                 at: CGPoint(x: bounds.minX, y: bounds.maxY - 26), into: context)
        context.setStrokeColor(CGColor(gray: 0.48, alpha: 1))
        context.setLineWidth(0.9)

        let boxSize: CGFloat = 18
        let rowSpacing: CGFloat = 37
        let firstBaseline = bounds.maxY - 83
        for y in stride(from: firstBaseline, through: bounds.minY, by: -rowSpacing) {
            context.addRect(CGRect(x: bounds.minX, y: y, width: boxSize, height: boxSize))
            context.move(to: CGPoint(x: bounds.minX + boxSize + 12, y: y))
            context.addLine(to: CGPoint(x: bounds.maxX, y: y))
        }
        context.strokePath()
    }

    private static func drawText(_ text: String, size: CGFloat, at point: CGPoint, into context: CGContext) {
        let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.17, alpha: 1)
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        context.textMatrix = .identity
        context.textPosition = point
        CTLineDraw(line, context)
    }
}
