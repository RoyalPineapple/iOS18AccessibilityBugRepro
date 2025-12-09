import XCTest
import UIKit

/// A view that stores a relative path and converts it to screen coordinates.
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
    
    // MARK: - Helper
    
    private func runMultipleReadTest(pathName: String, path: UIBezierPath, file: StaticString = #file, line: UInt = #line) {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "\(pathName) read \(i): expected X=\(expectedX), got \(p.bounds.origin.x)", file: file, line: line)
        }
        
        view.removeFromSuperview()
    }

    // MARK: - Path Types That Work (No Bug)
    
    func testRectPath_NoBug() {
        runMultipleReadTest(pathName: "rect", 
            path: UIBezierPath(rect: CGRect(x: 0, y: 0, width: 60, height: 40)))
    }
    
    func testOvalPath_NoBug() {
        runMultipleReadTest(pathName: "oval", 
            path: UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 60, height: 40)))
    }
    
    func testArcPath_NoBug() {
        runMultipleReadTest(pathName: "arc", 
            path: UIBezierPath(arcCenter: CGPoint(x: 30, y: 20), radius: 20, startAngle: 0, endAngle: .pi * 2, clockwise: true))
    }
    
    // MARK: - Path Types That Trigger Bug
    
    func testRoundedRectPath_HasBug() {
        runMultipleReadTest(pathName: "roundedRect", 
            path: UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10))
    }
    
    func testCustomLinePath_HasBug() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        path.addLine(to: CGPoint(x: 0, y: 40))
        path.close()
        runMultipleReadTest(pathName: "customLine", path: path)
    }
    
    func testQuadCurvePath_HasBug() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 20))
        path.addQuadCurve(to: CGPoint(x: 60, y: 20), controlPoint: CGPoint(x: 30, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: 20), controlPoint: CGPoint(x: 30, y: 40))
        path.close()
        runMultipleReadTest(pathName: "quadCurve", path: path)
    }
    
    func testCubicCurvePath_HasBug() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 20))
        path.addCurve(to: CGPoint(x: 60, y: 20), controlPoint1: CGPoint(x: 20, y: 0), controlPoint2: CGPoint(x: 40, y: 0))
        path.addCurve(to: CGPoint(x: 0, y: 20), controlPoint1: CGPoint(x: 40, y: 40), controlPoint2: CGPoint(x: 20, y: 40))
        path.close()
        runMultipleReadTest(pathName: "cubicCurve", path: path)
    }
    
    // MARK: - Edge Cases
    
    func testMoveOnlyPath() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 30, y: 20))
        // Path with only a move, no actual drawing
        runMultipleReadTest(pathName: "moveOnly", path: path)
    }
    
    func testSingleLinePath() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        runMultipleReadTest(pathName: "singleLine", path: path)
    }
}
