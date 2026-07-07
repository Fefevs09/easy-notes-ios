import XCTest
import CoreData

class ShapeObjectTests: XCTestCase {
    var inMemoryContext: NSManagedObjectContext!
    var viewModel: NoteViewModel!

    override func setUp() {
        super.setUp()
        (viewModel, inMemoryContext) = TestSupport.makeInMemoryViewModel()
    }

    override func tearDown() {
        viewModel = nil
        inMemoryContext = nil
        super.tearDown()
    }

    private func makeNote() -> Note {
        viewModel.addNote(title: "Shapes", content: "")
        return viewModel.notes.first!
    }

    @discardableResult
    private func addShape(to note: Note, kind: String, pageIndex: Int16,
                          points: String = "10.0,10.0;100.0,100.0",
                          fill: String? = nil) -> ShapeObject {
        let shape = ShapeObject(context: inMemoryContext)
        shape.id = UUID()
        shape.kind = kind
        shape.points = points
        shape.strokeColor = "#000000"
        shape.strokeWidth = 3.0
        shape.fillColor = fill
        shape.createdAt = Date()
        shape.pageIndex = pageIndex
        shape.note = note
        return shape
    }

    func testCreateShapeOfEachDrawableKindPersists() {
        // Given
        let note = makeNote()
        let kinds = ["line", "rectangle", "ellipse", "arrow"]

        // When
        for kind in kinds { addShape(to: note, kind: kind, pageIndex: 0) }
        try? inMemoryContext.save()
        viewModel.loadNotes()

        // Then
        let shapes = viewModel.notes.first?.shapes as? Set<ShapeObject> ?? []
        XCTAssertEqual(shapes.count, 4)
        XCTAssertEqual(Set(shapes.map { $0.kind }), Set(kinds))
    }

    func testShapesFilteredByPageIndex() {
        // Given
        let note = makeNote()
        addShape(to: note, kind: "line", pageIndex: 0)
        addShape(to: note, kind: "rectangle", pageIndex: 1)
        addShape(to: note, kind: "ellipse", pageIndex: 1)
        try? inMemoryContext.save()

        // Then
        let all = note.shapes as? Set<ShapeObject> ?? []
        XCTAssertEqual(all.filter { $0.pageIndex == 0 }.count, 1)
        XCTAssertEqual(all.filter { $0.pageIndex == 1 }.count, 2)
    }

    func testControlPointsRoundTrip() {
        // Given a shape whose control points are serialized like a stroke
        let note = makeNote()
        let shape = addShape(to: note, kind: "rectangle", pageIndex: 0,
                             points: "12.5,34.0;100.0,220.5")
        try? inMemoryContext.save()

        // When deserialized with the shared helper
        let pts = deserializeStrokePoints(shape.points)

        // Then
        XCTAssertEqual(pts.count, 2)
        XCTAssertEqual(pts[0].x, 12.5, accuracy: 0.01)
        XCTAssertEqual(pts[1].y, 220.5, accuracy: 0.01)
    }

    func testDeletingNoteCascadesShapes() {
        // Given
        let note = makeNote()
        addShape(to: note, kind: "line", pageIndex: 0)
        addShape(to: note, kind: "arrow", pageIndex: 0)
        try? inMemoryContext.save()

        // When
        inMemoryContext.delete(note)
        try? inMemoryContext.save()

        // Then
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ShapeObject")
        let remaining = (try? inMemoryContext.count(for: request)) ?? -1
        XCTAssertEqual(remaining, 0)
    }

    func testFillColorIsOptional() {
        // Given
        let note = makeNote()
        let stroked = addShape(to: note, kind: "line", pageIndex: 0, fill: nil)
        let filled = addShape(to: note, kind: "rectangle", pageIndex: 0, fill: "#FF000033")
        try? inMemoryContext.save()

        // Then
        XCTAssertNil(stroked.fillColor)
        XCTAssertEqual(filled.fillColor, "#FF000033")
    }
}
