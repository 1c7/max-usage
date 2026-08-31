import XCTest
@testable import OpenUsage

final class KeychainAccessorTests: XCTestCase {
    /// Returns a fixed `ProcessResult` for any invocation — lets us drive the accessor's exit-code
    /// handling without a real `security` subprocess.
    private struct StubRunner: ProcessRunning {
        let result: ProcessResult
        func run(executable: String, arguments: [String], environment: [String: String], timeout: TimeInterval) throws -> ProcessResult {
            result
        }
    }

    func testItemNotFoundExitReturnsNil() throws {
        // Exit 44 (errSecItemNotFound) is the legitimate "no credential stored" case → nil.
        let accessor = SecurityKeychainAccessor(processRunner: StubRunner(
            result: ProcessResult(exitCode: 44, stdout: "", stderr: "The specified item could not be found in the keychain.")
        ))
        XCTAssertNil(try accessor.readGenericPassword(service: "Test"))
    }

    func testDeniedInteractionThrowsAccessDenied() {
        // Exit 51 (unlock/interaction family): a prompt was shown and not accepted. This must throw
        // `accessDenied` — not collapse into the same nil as "no credential", and not be treated as
        // a plain read failure either, because callers back off on denial instead of retrying into
        // the next prompt.
        let accessor = SecurityKeychainAccessor(processRunner: StubRunner(
            result: ProcessResult(exitCode: 51, stdout: "", stderr: "User interaction is not allowed.")
        ))
        XCTAssertThrowsError(try accessor.readGenericPassword(service: "Test")) { error in
            guard case KeychainError.accessDenied = error else {
                return XCTFail("expected KeychainError.accessDenied, got \(error)")
            }
        }
    }

    func testNonItemNotFoundFailureThrowsReadFailed() {
        // Any other non-44 non-zero exit (locked keychain, access denied after the fact) must throw
        // `readFailed`, not collapse into the same nil as "no credential" — otherwise it gets
        // mislabeled "not signed in".
        let accessor = SecurityKeychainAccessor(processRunner: StubRunner(
            result: ProcessResult(exitCode: 1, stdout: "", stderr: "keychain is locked")
        ))
        XCTAssertThrowsError(try accessor.readGenericPassword(service: "Test")) { error in
            guard case KeychainError.readFailed = error else {
                return XCTFail("expected KeychainError.readFailed, got \(error)")
            }
        }
    }

    func testFoundValueIsReturnedTrimmed() throws {
        let accessor = SecurityKeychainAccessor(processRunner: StubRunner(
            result: ProcessResult(exitCode: 0, stdout: "secret-token\n", stderr: "")
        ))
        XCTAssertEqual(try accessor.readGenericPassword(service: "Test"), "secret-token")
    }
}
