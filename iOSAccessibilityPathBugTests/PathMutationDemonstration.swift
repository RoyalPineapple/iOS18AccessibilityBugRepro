import XCTest
import UIKit

/// Demonstrates the iOS 18+ bug where UIAccessibility.convertToScreenCoordinates
/// mutates its input UIBezierPath, causing output coordinates to drift on repeated reads.
///
/// Expected: Output path coordinates remain stable across multiple reads
/// Actual (iOS 18+): Output coordinates accumulate, drifting further each time
final class PathMutationDemonstration: XCTestCase {
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

    // MARK: - Core Bug Demonstration
    
    func test_coordinatesDriftOnRepeatedReads() {
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let initialBounds = path.bounds
        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        // Expected: All reads return the same coordinates
        // Actual (iOS 18+): Coordinates drift, test FAILS
        let first = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(first, expectedX, "1st read should return correct coordinates")

        let second = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(second, expectedX, "2nd read should return same coordinates (FAILS on iOS 18+)")

        let third = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(third, expectedX, "3rd read should return same coordinates (FAILS on iOS 18+)")

        // why do these pass, whats being mutated?
        XCTAssert(path === view.relativePath, "relative path should not change")
        XCTAssertEqual(initialBounds, path.bounds)
        XCTAssertEqual(initialBounds, view.relativePath?.bounds)
    }

    func test_roundedRectPath_coordinatesDriftOnRepeatedReads() {
        // CGPath with rounded rect - affected by bug
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        // Expected: All reads return the same coordinates
        // Actual (iOS 18+): Coordinates drift, test FAILS
        let first = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(first, expectedX, "1st read should return correct coordinates")

        let second = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(second, expectedX, "2nd read should return same coordinates (FAILS on iOS 18+)")

        let third = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(third, expectedX, "3rd read should return same coordinates (FAILS on iOS 18+)")
    }
    
    func test_cgPathWithQuadCurve_coordinatesDriftOnRepeatedReads() {
        // CGPath with quadCurve elements - affected by bug
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let cgPath = CGMutablePath()
        cgPath.move(to: .zero)
        cgPath.addQuadCurve(to: CGPoint(x: 60, y: 40), control: CGPoint(x: 15, y: 30))
        let path = UIBezierPath(cgPath: cgPath)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        let first = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(first, expectedX, "1st read should return correct coordinates")

        let second = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(second, expectedX, "2nd read should return same coordinates (FAILS on iOS 18+)")

        let third = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(third, expectedX, "3rd read should return same coordinates (FAILS on iOS 18+)")
    }

    func test_cgPathWithLines_coordinatesDriftOnRepeatedReads() {
        // CGPath with line elements - affected by bug
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 0, y: 40))
        cgPath.addLine(to: CGPoint(x: 20, y: 15))
        cgPath.addLine(to: CGPoint(x: 40, y: 25))
        cgPath.addLine(to: CGPoint(x: 60, y: 0))
        let path = UIBezierPath(cgPath: cgPath)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        let first = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(first, expectedX, "1st read should return correct coordinates")

        let second = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(second, expectedX, "2nd read should return same coordinates (FAILS on iOS 18+)")

        let third = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(third, expectedX, "3rd read should return same coordinates (FAILS on iOS 18+)")
    }

    func test_rectPath_coordinatesStableOnRepeatedReads() {
        // rect is not affected by bug
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "1st read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "2nd read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "3rd read")
    }

    func test_ovalPath_coordinatesStableOnRepeatedReads() {
        // ovalIn is not affected by bug
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "1st read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "2nd read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "3rd read")
    }

    func test_arcCenterPath_coordinatesStableOnRepeatedReads() {
        // arcCenter is not affected by bug
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(arcCenter: CGPoint(x: 30, y: 20), radius: 20,
                                startAngle: 0, endAngle: 1.57, clockwise: true)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "1st read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "2nd read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "3rd read")
    }


    // MARK: - Mutation Investigation

    func test_detailedMutationDiagnostics() {
        // Comprehensive logging to understand what gets mutated
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let initialBounds = path.bounds
        let initialCGPath = path.cgPath
        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        XCTFail("""
        === INITIAL STATE ===
        Input path bounds: \(path.bounds)
        Input CGPath pointer: \(Unmanaged.passUnretained(path.cgPath).toOpaque())
        Expected X: \(expectedX)
        """)

        let firstPath = view.accessibilityPath!
        let first = firstPath.bounds.origin.x
        XCTFail("""
        === AFTER 1ST READ ===
        Returned path bounds: \(firstPath.bounds)
        Returned CGPath pointer: \(Unmanaged.passUnretained(firstPath.cgPath).toOpaque())
        Input path bounds: \(path.bounds)
        Input CGPath pointer: \(Unmanaged.passUnretained(path.cgPath).toOpaque())
        CGPath same? \(initialCGPath == path.cgPath)
        Returned X: \(first), Expected: \(expectedX)
        """)

        let secondPath = view.accessibilityPath!
        let second = secondPath.bounds.origin.x
        XCTFail("""
        === AFTER 2ND READ ===
        Returned path bounds: \(secondPath.bounds)
        Returned CGPath pointer: \(Unmanaged.passUnretained(secondPath.cgPath).toOpaque())
        Input path bounds: \(path.bounds)
        Input CGPath pointer: \(Unmanaged.passUnretained(path.cgPath).toOpaque())
        CGPath same? \(initialCGPath == path.cgPath)
        Returned X: \(second), Expected: \(expectedX)
        """)

        let thirdPath = view.accessibilityPath!
        let third = thirdPath.bounds.origin.x
        XCTFail("""
        === AFTER 3RD READ ===
        Returned path bounds: \(thirdPath.bounds)
        Returned CGPath pointer: \(Unmanaged.passUnretained(thirdPath.cgPath).toOpaque())
        Input path bounds: \(path.bounds)
        Input CGPath pointer: \(Unmanaged.passUnretained(path.cgPath).toOpaque())
        CGPath same? \(initialCGPath == path.cgPath)
        Returned X: \(third), Expected: \(expectedX)
        """)

        XCTFail("""
        === SUMMARY ===
        Input UIBezierPath unchanged: \(path === view.relativePath)
        Input bounds unchanged: \(initialBounds == path.bounds)
        Input CGPath pointer unchanged: \(initialCGPath == path.cgPath)
        """)
    }

    func test_returnedPathIdentity() {
        // Do we get the same path object back, or a new one each time?
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let first = view.accessibilityPath!
        let second = view.accessibilityPath!
        let third = view.accessibilityPath!

        XCTFail("""
        === RETURNED PATH IDENTITY ===
        1st and 2nd same object? \(first === second)
        2nd and 3rd same object? \(second === third)
        1st and input same object? \(first === path)
        1st bounds: \(first.bounds)
        2nd bounds: \(second.bounds)
        3rd bounds: \(third.bounds)
        """)
    }

    func test_heldPathMutation() {
        // If we hold onto a returned path, does it change?
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let heldPath = view.accessibilityPath!
        let heldBounds = heldPath.bounds

        XCTFail("""
        === HELD PATH MUTATION ===
        Held path initial bounds: \(heldBounds)
        """)

        _ = view.accessibilityPath  // trigger another read
        XCTFail("""
        After 2nd read, held path bounds: \(heldPath.bounds)
        Held path mutated? \(heldPath.bounds != heldBounds)
        """)

        _ = view.accessibilityPath  // trigger another read
        XCTFail("""
        After 3rd read, held path bounds: \(heldPath.bounds)
        Held path mutated? \(heldPath.bounds != heldBounds)
        """)
    }

    func test_directConversionCall() {
        // What happens when we call convertToScreenCoordinates directly?
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()

        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        let initialBounds = path.bounds

        XCTFail("""
        === DIRECT CONVERSION ===
        Initial path bounds: \(initialBounds)
        """)

        let converted1 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        XCTFail("""
        After 1st conversion:
          Input path bounds: \(path.bounds)
          Returned path bounds: \(converted1.bounds)
          Same object? \(path === converted1)
        """)

        let converted2 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        XCTFail("""
        After 2nd conversion:
          Input path bounds: \(path.bounds)
          Returned path bounds: \(converted2.bounds)
          Same object? \(path === converted2)
        """)

        let converted3 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        XCTFail("""
        After 3rd conversion:
          Input path bounds: \(path.bounds)
          Returned path bounds: \(converted3.bounds)
          Same object? \(path === converted3)
        """)
    }

    // MARK: - Other Trigger Conditions

    func test_detachedView_noCoordinateDrift() {
        // Bug only occurs when view is in a visible window hierarchy
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        // Note: view NOT added to window

        let original = path.bounds

        _ = view.accessibilityPath
        _ = view.accessibilityPath
        _ = view.accessibilityPath

        XCTAssertEqual(path.bounds, original, "Detached view: no mutation occurs")
    }

    // MARK: - Workaround Verification

    func test_workaround_copyPath_coordinatesStable() {
        // Workaround: copying the path prevents mutation and drift
        let view = FixedPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "1st read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "2nd read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "3rd read")
        XCTAssertEqual(path.bounds.origin.x, 0, accuracy: 0.1, "Original path unchanged")
    }
}

// MARK: - Test Helpers

/// View that implements accessibilityPath using the documented pattern
private class BuggyPathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { fatalError("use relativePath instead") }
    }
}

/// View that implements the workaround by copying the path
private class FixedPathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath?.copy() as? UIBezierPath else { return nil }
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { fatalError("use relativePath instead") }
    }
}
