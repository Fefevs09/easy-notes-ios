import XCTest
import Foundation

@main
struct TestRunner {
    static func main() {
        class TestObserver: NSObject, XCTestObservation {
            func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int) {
                print("❌ \(testCase.name) FAILED at \(filePath ?? "unknown"):\(lineNumber) - \(description)")
            }
            
            func testCaseDidFinish(_ testCase: XCTestCase) {
                if testCase.testRun?.hasSucceeded == true {
                    print("✅ \(testCase.name) PASSED")
                }
            }
        }

        let observer = TestObserver()
        XCTestObservationCenter.shared.addTestObserver(observer)

        let suite = XCTestSuite(name: "EasyNotesTests")
        suite.addTest(XCTestSuite(forTestCaseClass: NoteViewModelTests.self))
        suite.addTest(XCTestSuite(forTestCaseClass: PDFExportTests.self))
        suite.addTest(XCTestSuite(forTestCaseClass: ShapeObjectTests.self))
        print("🏃 Running \(suite.testCaseCount) tests...")
        suite.run()
        let run = suite.testRun

        print("\n--- Test Summary ---")
        print("Executed: \(run?.testCaseCount ?? 0) tests")
        print("Failures: \(run?.failureCount ?? 0)")
        print("Unexpected Exceptions: \(run?.unexpectedExceptionCount ?? 0)")

        if let run = run, run.failureCount == 0 && run.unexpectedExceptionCount == 0 {
            print("🎉 All tests passed!")
            exit(0)
        } else {
            print("❌ Some tests failed.")
            exit(1)
        }
    }
}
