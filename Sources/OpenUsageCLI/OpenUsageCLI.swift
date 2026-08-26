import Darwin
import Foundation
import OpenUsage

@main
struct OpenUsageCLI {
    static func main() async {
        do {
            let arguments = try CLIArguments.parse(Array(CommandLine.arguments.dropFirst()))
            if arguments.showHelp {
                print(help)
                return
            }

            let app = AppBundleLocator.locate()
            if arguments.showVersion {
                print(app.version.map { "maxusage \($0)" } ?? "maxusage (development build)")
                return
            }

            guard let defaults = UserDefaults(suiteName: app.bundleIdentifier) else {
                throw CLIError.appDefaultsUnavailable
            }
            let result = try await UsageReader(userDefaults: defaults).read(
                providerID: arguments.providerID,
                force: arguments.force
            )
            FileHandle.standardOutput.write(result.data)
            FileHandle.standardOutput.write(Data("\n".utf8))
            if !result.warnings.isEmpty {
                result.warnings.forEach { writeError("warning: \($0)") }
                exit(4)
            }
        } catch CLIError.usage(let message) {
            fail("\(message)\nRun 'maxusage --help' for usage.", code: 2)
        } catch CLIError.appDefaultsUnavailable {
            fail("Could not open the MaxUsage settings domain.", code: 4)
        } catch UsageReaderError.unknownProvider(let providerID) {
            fail("Unknown provider: \(providerID)", code: 2)
        } catch {
            fail(error.localizedDescription, code: 4)
        }
    }

    private static func writeError(_ message: String) {
        FileHandle.standardError.write(Data("maxusage: \(message)\n".utf8))
    }

    private static func fail(_ message: String, code: Int32) -> Never {
        writeError(message)
        exit(code)
    }

    private static let help = """
    Usage: maxusage [provider] [--force]

    Read limits through MaxUsage's shared five-minute cache and exit. Output is always JSON.

    Options:
      --force      Refresh even when the shared cache is still fresh
      -v, --version
      -h, --help
    """
}
