import CoreData

public class CoreDataStack {
    public static let shared = CoreDataStack()
    
    public let container: NSPersistentContainer
    
    public var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // --- 1. Entity: Notebook ---
        let notebookEntity = NSEntityDescription()
        notebookEntity.name = "Notebook"
        notebookEntity.managedObjectClassName = "Notebook"
        
        let notebookIdAttribute = NSAttributeDescription()
        notebookIdAttribute.name = "id"
        notebookIdAttribute.attributeType = .UUIDAttributeType
        notebookIdAttribute.isOptional = false
        
        let notebookNameAttribute = NSAttributeDescription()
        notebookNameAttribute.name = "name"
        notebookNameAttribute.attributeType = .stringAttributeType
        notebookNameAttribute.isOptional = false
        
        notebookEntity.properties = [notebookIdAttribute, notebookNameAttribute]
        
        // --- 2. Entity: Note ---
        let noteEntity = NSEntityDescription()
        noteEntity.name = "Note"
        noteEntity.managedObjectClassName = "Note"
        
        let noteIdAttribute = NSAttributeDescription()
        noteIdAttribute.name = "id"
        noteIdAttribute.attributeType = .UUIDAttributeType
        noteIdAttribute.isOptional = false
        
        let noteTitleAttribute = NSAttributeDescription()
        noteTitleAttribute.name = "title"
        noteTitleAttribute.attributeType = .stringAttributeType
        noteTitleAttribute.isOptional = false
        
        let noteContentAttribute = NSAttributeDescription()
        noteContentAttribute.name = "content"
        noteContentAttribute.attributeType = .stringAttributeType
        noteContentAttribute.isOptional = false
        
        let noteCreatedAtAttribute = NSAttributeDescription()
        noteCreatedAtAttribute.name = "createdAt"
        noteCreatedAtAttribute.attributeType = .dateAttributeType
        noteCreatedAtAttribute.isOptional = false
        
        let noteUpdatedAtAttribute = NSAttributeDescription()
        noteUpdatedAtAttribute.name = "updatedAt"
        noteUpdatedAtAttribute.attributeType = .dateAttributeType
        noteUpdatedAtAttribute.isOptional = false
        
        let noteIsTrashedAttribute = NSAttributeDescription()
        noteIsTrashedAttribute.name = "isTrashed"
        noteIsTrashedAttribute.attributeType = .booleanAttributeType
        noteIsTrashedAttribute.isOptional = false
        noteIsTrashedAttribute.defaultValue = false
        
        let notePdfDataAttribute = NSAttributeDescription()
        notePdfDataAttribute.name = "pdfData"
        notePdfDataAttribute.attributeType = .binaryDataAttributeType
        notePdfDataAttribute.isOptional = true
        
        let notePageCountAttribute = NSAttributeDescription()
        notePageCountAttribute.name = "pageCount"
        notePageCountAttribute.attributeType = .integer16AttributeType
        notePageCountAttribute.isOptional = false
        notePageCountAttribute.defaultValue = 1

        let noteGridStyleAttribute = NSAttributeDescription()
        noteGridStyleAttribute.name = "gridStyle"
        noteGridStyleAttribute.attributeType = .stringAttributeType
        noteGridStyleAttribute.isOptional = false
        noteGridStyleAttribute.defaultValue = "none"

        let noteGridSpacingAttribute = NSAttributeDescription()
        noteGridSpacingAttribute.name = "gridSpacing"
        noteGridSpacingAttribute.attributeType = .floatAttributeType
        noteGridSpacingAttribute.isOptional = false
        noteGridSpacingAttribute.defaultValue = 24.0

        let noteGridOriginXAttribute = NSAttributeDescription()
        noteGridOriginXAttribute.name = "gridOriginX"
        noteGridOriginXAttribute.attributeType = .floatAttributeType
        noteGridOriginXAttribute.isOptional = false
        noteGridOriginXAttribute.defaultValue = 0.0

        let noteGridOriginYAttribute = NSAttributeDescription()
        noteGridOriginYAttribute.name = "gridOriginY"
        noteGridOriginYAttribute.attributeType = .floatAttributeType
        noteGridOriginYAttribute.isOptional = false
        noteGridOriginYAttribute.defaultValue = 0.0

        noteEntity.properties = [
            noteIdAttribute,
            noteTitleAttribute,
            noteContentAttribute,
            noteCreatedAtAttribute,
            noteUpdatedAtAttribute,
            noteIsTrashedAttribute,
            notePdfDataAttribute,
            notePageCountAttribute,
            noteGridStyleAttribute,
            noteGridSpacingAttribute,
            noteGridOriginXAttribute,
            noteGridOriginYAttribute
        ]
        
        // --- 3. Entity: Stroke ---
        let strokeEntity = NSEntityDescription()
        strokeEntity.name = "Stroke"
        strokeEntity.managedObjectClassName = "Stroke"
        
        let strokeIdAttribute = NSAttributeDescription()
        strokeIdAttribute.name = "id"
        strokeIdAttribute.attributeType = .UUIDAttributeType
        strokeIdAttribute.isOptional = false
        
        let strokePointsAttribute = NSAttributeDescription()
        strokePointsAttribute.name = "points"
        strokePointsAttribute.attributeType = .stringAttributeType
        strokePointsAttribute.isOptional = false
        
        let strokeColorAttribute = NSAttributeDescription()
        strokeColorAttribute.name = "color"
        strokeColorAttribute.attributeType = .stringAttributeType
        strokeColorAttribute.isOptional = false
        
        let strokeWidthAttribute = NSAttributeDescription()
        strokeWidthAttribute.name = "width"
        strokeWidthAttribute.attributeType = .floatAttributeType
        strokeWidthAttribute.isOptional = false
        
        let strokeCreatedAtAttribute = NSAttributeDescription()
        strokeCreatedAtAttribute.name = "createdAt"
        strokeCreatedAtAttribute.attributeType = .dateAttributeType
        strokeCreatedAtAttribute.isOptional = false
        
        let strokePageIndexAttribute = NSAttributeDescription()
        strokePageIndexAttribute.name = "pageIndex"
        strokePageIndexAttribute.attributeType = .integer16AttributeType
        strokePageIndexAttribute.isOptional = false
        strokePageIndexAttribute.defaultValue = 0
        
        strokeEntity.properties = [
            strokeIdAttribute,
            strokePointsAttribute,
            strokeColorAttribute,
            strokeWidthAttribute,
            strokeCreatedAtAttribute,
            strokePageIndexAttribute
        ]

        // --- 3b. Entity: ShapeObject ---
        let shapeEntity = NSEntityDescription()
        shapeEntity.name = "ShapeObject"
        shapeEntity.managedObjectClassName = "ShapeObject"

        let shapeIdAttribute = NSAttributeDescription()
        shapeIdAttribute.name = "id"
        shapeIdAttribute.attributeType = .UUIDAttributeType
        shapeIdAttribute.isOptional = false

        let shapeKindAttribute = NSAttributeDescription()
        shapeKindAttribute.name = "kind"
        shapeKindAttribute.attributeType = .stringAttributeType
        shapeKindAttribute.isOptional = false

        let shapePointsAttribute = NSAttributeDescription()
        shapePointsAttribute.name = "points"
        shapePointsAttribute.attributeType = .stringAttributeType
        shapePointsAttribute.isOptional = false

        let shapeStrokeColorAttribute = NSAttributeDescription()
        shapeStrokeColorAttribute.name = "strokeColor"
        shapeStrokeColorAttribute.attributeType = .stringAttributeType
        shapeStrokeColorAttribute.isOptional = false

        let shapeStrokeWidthAttribute = NSAttributeDescription()
        shapeStrokeWidthAttribute.name = "strokeWidth"
        shapeStrokeWidthAttribute.attributeType = .floatAttributeType
        shapeStrokeWidthAttribute.isOptional = false

        let shapeFillColorAttribute = NSAttributeDescription()
        shapeFillColorAttribute.name = "fillColor"
        shapeFillColorAttribute.attributeType = .stringAttributeType
        shapeFillColorAttribute.isOptional = true

        let shapeCreatedAtAttribute = NSAttributeDescription()
        shapeCreatedAtAttribute.name = "createdAt"
        shapeCreatedAtAttribute.attributeType = .dateAttributeType
        shapeCreatedAtAttribute.isOptional = false

        let shapePageIndexAttribute = NSAttributeDescription()
        shapePageIndexAttribute.name = "pageIndex"
        shapePageIndexAttribute.attributeType = .integer16AttributeType
        shapePageIndexAttribute.isOptional = false
        shapePageIndexAttribute.defaultValue = 0

        shapeEntity.properties = [
            shapeIdAttribute,
            shapeKindAttribute,
            shapePointsAttribute,
            shapeStrokeColorAttribute,
            shapeStrokeWidthAttribute,
            shapeFillColorAttribute,
            shapeCreatedAtAttribute,
            shapePageIndexAttribute
        ]

        // --- 4. Relationships ---
        // Notebook -> Note (One-to-Many, cascade delete)
        let notebookToNotesRelation = NSRelationshipDescription()
        notebookToNotesRelation.name = "notes"
        notebookToNotesRelation.destinationEntity = noteEntity
        notebookToNotesRelation.minCount = 0
        notebookToNotesRelation.maxCount = 0 // unlimited
        notebookToNotesRelation.deleteRule = .cascadeDeleteRule
        
        // Note -> Notebook (Many-to-One, nullify delete)
        let noteToNotebookRelation = NSRelationshipDescription()
        noteToNotebookRelation.name = "notebook"
        noteToNotebookRelation.destinationEntity = notebookEntity
        noteToNotebookRelation.minCount = 0
        noteToNotebookRelation.maxCount = 1
        noteToNotebookRelation.deleteRule = .nullifyDeleteRule
        
        notebookToNotesRelation.inverseRelationship = noteToNotebookRelation
        noteToNotebookRelation.inverseRelationship = notebookToNotesRelation
        
        // Note -> Stroke (One-to-Many, cascade delete)
        let noteToStrokesRelation = NSRelationshipDescription()
        noteToStrokesRelation.name = "strokes"
        noteToStrokesRelation.destinationEntity = strokeEntity
        noteToStrokesRelation.minCount = 0
        noteToStrokesRelation.maxCount = 0 // unlimited
        noteToStrokesRelation.deleteRule = .cascadeDeleteRule
        
        // Stroke -> Note (Many-to-One, nullify delete)
        let strokeToNoteRelation = NSRelationshipDescription()
        strokeToNoteRelation.name = "note"
        strokeToNoteRelation.destinationEntity = noteEntity
        strokeToNoteRelation.minCount = 0
        strokeToNoteRelation.maxCount = 1
        strokeToNoteRelation.deleteRule = .nullifyDeleteRule
        
        noteToStrokesRelation.inverseRelationship = strokeToNoteRelation
        strokeToNoteRelation.inverseRelationship = noteToStrokesRelation

        // Note -> ShapeObject (One-to-Many, cascade delete)
        let noteToShapesRelation = NSRelationshipDescription()
        noteToShapesRelation.name = "shapes"
        noteToShapesRelation.destinationEntity = shapeEntity
        noteToShapesRelation.minCount = 0
        noteToShapesRelation.maxCount = 0 // unlimited
        noteToShapesRelation.deleteRule = .cascadeDeleteRule

        // ShapeObject -> Note (Many-to-One, nullify delete)
        let shapeToNoteRelation = NSRelationshipDescription()
        shapeToNoteRelation.name = "note"
        shapeToNoteRelation.destinationEntity = noteEntity
        shapeToNoteRelation.minCount = 0
        shapeToNoteRelation.maxCount = 1
        shapeToNoteRelation.deleteRule = .nullifyDeleteRule

        noteToShapesRelation.inverseRelationship = shapeToNoteRelation
        shapeToNoteRelation.inverseRelationship = noteToShapesRelation

        // Add relationships to entities
        notebookEntity.properties.append(notebookToNotesRelation)
        noteEntity.properties.append(noteToNotebookRelation)
        noteEntity.properties.append(noteToStrokesRelation)
        noteEntity.properties.append(noteToShapesRelation)
        strokeEntity.properties.append(strokeToNoteRelation)
        shapeEntity.properties.append(shapeToNoteRelation)

        // --- 5. Configure Model ---
        model.entities = [notebookEntity, noteEntity, strokeEntity, shapeEntity]
        
        return model
    }

    private init() {
        container = NSPersistentContainer(name: "EasyNotesModel", managedObjectModel: Self.makeModel())
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    public func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
