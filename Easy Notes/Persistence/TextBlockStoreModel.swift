import CoreData

extension CoreDataStack {
    static func addTextBlockEntity(to model: NSManagedObjectModel) {
        guard let noteEntity = model.entitiesByName["Note"] else { return }

        let textBlockEntity = NSEntityDescription()
        textBlockEntity.name = "TextBlock"
        textBlockEntity.managedObjectClassName = "TextBlock"

        func attribute(
            _ name: String,
            type: NSAttributeType,
            defaultValue: Any? = nil
        ) -> NSAttributeDescription {
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.isOptional = false
            if let defaultValue {
                attribute.defaultValue = defaultValue
            }
            return attribute
        }

        let noteToTextBlocks = NSRelationshipDescription()
        noteToTextBlocks.name = "textBlocks"
        noteToTextBlocks.destinationEntity = textBlockEntity
        noteToTextBlocks.isOptional = true
        noteToTextBlocks.minCount = 0
        noteToTextBlocks.maxCount = 0
        noteToTextBlocks.deleteRule = .cascadeDeleteRule

        let textBlockToNote = NSRelationshipDescription()
        textBlockToNote.name = "note"
        textBlockToNote.destinationEntity = noteEntity
        textBlockToNote.isOptional = true
        textBlockToNote.minCount = 0
        textBlockToNote.maxCount = 1
        textBlockToNote.deleteRule = .nullifyDeleteRule

        noteToTextBlocks.inverseRelationship = textBlockToNote
        textBlockToNote.inverseRelationship = noteToTextBlocks

        textBlockEntity.properties = [
            attribute("id", type: .UUIDAttributeType),
            attribute("text", type: .stringAttributeType, defaultValue: ""),
            attribute("x", type: .doubleAttributeType, defaultValue: 0.0),
            attribute("y", type: .doubleAttributeType, defaultValue: 0.0),
            attribute("width", type: .doubleAttributeType, defaultValue: Double(TextBlockLayout.defaultSize.width)),
            attribute("height", type: .doubleAttributeType, defaultValue: Double(TextBlockLayout.defaultSize.height)),
            attribute("fontSize", type: .floatAttributeType, defaultValue: Float(TextBlockLayout.defaultFontSize)),
            attribute("colorHex", type: .stringAttributeType, defaultValue: TextBlockLayout.defaultColorHex),
            attribute("pageIndex", type: .integer16AttributeType, defaultValue: Int16(0)),
            attribute("createdAt", type: .dateAttributeType),
            attribute("updatedAt", type: .dateAttributeType),
            textBlockToNote
        ]

        noteEntity.properties.append(noteToTextBlocks)
        model.entities.append(textBlockEntity)
    }
}
