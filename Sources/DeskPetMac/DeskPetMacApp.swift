import AppKit
import SwiftUI

@main
struct DeskPetMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = PetViewModel()

    var body: some Scene {
        WindowGroup {
            PetWindowView(model: model)
                .frame(width: 220, height: 250)
                .task {
                    await model.start()
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Pet") {
                Button("Pat") { model.pat() }
                    .keyboardShortcut("p", modifiers: [.command])
                Button("Dance") { model.dance() }
                    .keyboardShortcut("d", modifiers: [.command])
                Button("Use Cat") { model.selectPetKind(.cat) }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("Use Pauli") { model.selectPetKind(.pauli) }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("Use Dog") { model.selectPetKind(.dog) }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("Take Break") { model.takeBreak() }
                    .keyboardShortcut("b", modifiers: [.command])
                Button("Refresh Weather") {
                    Task { await model.refreshWeather() }
                }
                .keyboardShortcut("r", modifiers: [.command])
                Button("Quit DeskPet") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }
    }
}
