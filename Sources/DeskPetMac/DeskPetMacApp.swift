import AppKit
import DeskPetCore
import SwiftUI

@main
struct DeskPetMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            PetMenuView(model: appDelegate.model)
        } label: {
            Label("DeskPet", systemImage: "pawprint.fill")
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandMenu("DeskPet") {
                Button("Pat") {
                    appDelegate.model.pat()
                }
                .keyboardShortcut("p", modifiers: .command)

                Button("Dance") {
                    appDelegate.model.dance()
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Give Treat") {
                    appDelegate.model.giveTreat()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Take a Stroll") {
                    appDelegate.model.takeStroll()
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Take a Break") {
                    appDelegate.model.takeBreak()
                }
                .keyboardShortcut("b", modifiers: .command)

                Divider()

                Button("Use Cat") {
                    appDelegate.model.selectPetKind(.cat)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Use Pauli") {
                    appDelegate.model.selectPetKind(.pauli)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Use Dog") {
                    appDelegate.model.selectPetKind(.dog)
                }
                .keyboardShortcut("3", modifiers: .command)

                Divider()

                Button("Refresh Weather") {
                    Task { await appDelegate.model.refreshWeather() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
