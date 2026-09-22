#if DEBUG
import Foundation

/// Pure descriptor probe; deliberately does not launch an unimplemented screen.
@main
struct RegistryProbe {
    static func main() {
        do {
        if CommandLine.arguments.count == 1 {
            FileHandle.standardOutput.write(try ScenarioRegistry.canonicalData())
        } else {
            let id = CommandLine.arguments[1]
            let variant = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "base"
            let selection = try ScenarioRegistry.resolve(id, variant: variant)
            print("\(selection.stableID): \(selection.story.status); node=\(selection.story.node); scene=\(selection.story.expectedScene)")
            exit(2)
        }
        } catch {
            FileHandle.standardError.write(Data("Fixture rejected: \(error)\n".utf8))
            exit(1)
        }
    }
}
#endif
