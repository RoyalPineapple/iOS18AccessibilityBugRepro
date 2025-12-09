import XCTest
import UIKit

/// A view that stores a relative path and converts it to screen coordinates.
/// BUG: On iOS 18, each access causes the stored path to be mutated.
private class BuggyAccessibilityPathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { super.accessibilityPath = newValue }
    }
}

final class AccessibilityPathMutationTests: XCTestCase {
    var window: UIWindow!
    var testView: UIView!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        testView = UIView(frame: window.bounds)
        window.addSubview(testView)
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        testView = nil
        super.tearDown()
    }

    /// Demonstrates iOS 18 bug: reading accessibilityPath multiple times causes coordinates to accumulate.
    func testAccessibilityPathMutationBug() {
        let customView = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        customView.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 20)
        testView.addSubview(customView)
        window.layoutIfNeeded()
        
        let viewScreenFrame = customView.convert(customView.bounds, to: nil)
        
        // Read accessibilityPath 5 times - on iOS 18, coordinates accumulate with each read
        for i in 1...5 {
            guard let path = customView.accessibilityPath else {
                XCTFail("accessibilityPath is nil on read \(i)")
                continue
            }
            
            XCTAssertEqual(path.bounds.origin.x, viewScreenFrame.origin.x, accuracy: 1.0,
                "Read \(i): Path X should be \(viewScreenFrame.origin.x), got \(path.bounds.origin.x)")
            XCTAssertEqual(path.bounds.origin.y, viewScreenFrame.origin.y, accuracy: 1.0,
                "Read \(i): Path Y should be \(viewScreenFrame.origin.y), got \(path.bounds.origin.y)")
        }
    }
}
