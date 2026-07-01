//
//  Easy_NotesApp.swift
//  Easy Notes
//
//  Created by Felipe Vieira on 25/05/26.
//

import SwiftUI

@main
struct Easy_NotesApp: App {
    let coreDataStack = CoreDataStack.shared
    @StateObject private var viewModel: NoteViewModel
    
    init() {
        let context = CoreDataStack.shared.viewContext
        _viewModel = StateObject(wrappedValue: NoteViewModel(context: context))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataStack.viewContext)
                .environmentObject(viewModel)
                .accentColor(Color(red: 0.91, green: 0.35, blue: 0.14))
                .preferredColorScheme(.light)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}
