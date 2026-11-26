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
    @StateObject private var welcome = WelcomeState.shared
    @StateObject private var settings = AppSettingsStore.shared
    
    init() {
        let context = CoreDataStack.shared.viewContext
        _viewModel = StateObject(wrappedValue: NoteViewModel(context: context))
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if welcome.showsWelcome {
                    WelcomeView {
                        viewModel.selectedNote = nil
                        welcome.complete()
                    }
                } else {
                    TutorialWorkspace(welcome: welcome, hasOpenNote: viewModel.selectedNote != nil) {
                        ContentView()
                    }
                }
            }
            .frame(minWidth: 920, minHeight: 600)
            .environment(\.managedObjectContext, coreDataStack.viewContext)
            .environmentObject(viewModel)
            .environmentObject(settings)
            .tint(PixelTheme.accent)
            .contrast(settings.interfaceContrast)
            .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        }
        .defaultSize(width: 1180, height: 760)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)

        Settings {
            AppSettingsView()
                .environmentObject(settings)
                .environmentObject(viewModel)
                .tint(PixelTheme.accent)
                .contrast(settings.interfaceContrast)
        }
    }
}
