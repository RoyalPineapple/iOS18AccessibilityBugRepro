# UIAccessibility.convertToScreenCoordinates mutates input UIBezierPath on iOS 18+

## Summary

`UIAccessibility.convertToScreenCoordinates(_:in:)` mutates the input `UIBezierPath` in-place on iOS 18 and later. This violates the documented API contract which states it **"returns a new path object with the results"**.

> "Converts the specified path object to screen coordinates and **returns a new path object** with the results."
> — [Apple Developer Documentation](https://developer.apple.com/documentation/uikit/uiaccessibility/1615139-converttoscreencoordinates)

## Environment

- iOS 18.0+ (tested on 18.5 and 26.1)
- Does NOT occur on iOS 17.5 and earlier
- Xcode 16.4 / Xcode 26.1

## Root Cause

The bug affects paths that contain **explicit path elements** internally. Paths using optimized internal representations (from convenience initializers) are unaffected.

### Works Correctly (No Bug)
| Path Type | Notes |
|-----------|-------|
| `UIBezierPath(rect:)` | Convenience initializer |
| `UIBezierPath(ovalIn:)` | Convenience initializer |
| `UIBezierPath(arcCenter:...)` | Convenience initializer |
| `CGPath(rect:)` → `UIBezierPath(cgPath:)` | CGPath rect also works |
| Empty path | No elements to mutate |
| View at origin (0,0) | Bug exists but 0+0=0 so not observable |

### Has Bug (Coordinates Accumulate)
| Path Type | Notes |
|-----------|-------|
| `UIBezierPath(roundedRect:cornerRadius:)` | Uses curves internally |
| `path.move(to:)` | Explicit element |
| `path.addLine(to:)` | Explicit element |
| `path.addQuadCurve(to:controlPoint:)` | Explicit element |
| `path.addCurve(to:controlPoint1:controlPoint2:)` | Explicit element |
| `path.close()` | Explicit element |
| `CGMutablePath` with `addLine` | CGPath explicit elements also affected |

### Operations That Break Working Paths
| Operation | Result |
|-----------|--------|
| `rect.addLine(to:)` | ❌ Adding line to rect breaks it |
| `oval.addLine(to:)` | ❌ Adding line to oval breaks it |
| `rect.append(linePath)` | ❌ Appending line path breaks it |
| `linePath.append(rect)` | ❌ Line path stays broken even with rect appended |
| `rect.reversing()` | ❌ Reversing converts to explicit elements, breaks it |
| `linePath.copy()` | ❌ Copying preserves the bug |
| `linePath.apply(transform)` | ❌ Transform doesn't fix it |

## Steps to Reproduce

1. Create a `UIView` subclass that stores a `UIBezierPath` in local coordinates
2. Override `accessibilityPath` to convert using `UIAccessibility.convertToScreenCoordinates`
3. Use a path with explicit elements (e.g., `addLine` or `roundedRect`)
4. Read `accessibilityPath` multiple times

```swift
class CustomView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { super.accessibilityPath = newValue }
    }
}

// This triggers the bug:
view.relativePath = UIBezierPath(roundedRect: rect, cornerRadius: 10)
let _ = view.accessibilityPath  // Read 1: correct
let _ = view.accessibilityPath  // Read 2: coordinates doubled!
let _ = view.accessibilityPath  // Read 3: coordinates tripled!
```

## Expected vs Actual Results

**Expected** (iOS 17 behavior):
```
Read 1: origin=(100.0, 200.0)
Read 2: origin=(100.0, 200.0)
Read 3: origin=(100.0, 200.0)
```

**Actual** (iOS 18+ with affected path types):
```
Read 1: origin=(100.0, 200.0)   ← correct
Read 2: origin=(200.0, 400.0)   ← doubled!
Read 3: origin=(300.0, 600.0)   ← tripled!
```

## Workaround

Copy the path before calling `convertToScreenCoordinates`:

```swift
override var accessibilityPath: UIBezierPath? {
    get {
        guard let path = relativePath else { return nil }
        let pathCopy = path.copy() as! UIBezierPath
        return UIAccessibility.convertToScreenCoordinates(pathCopy, in: self)
    }
    set { super.accessibilityPath = newValue }
}
```

## Running the Tests

```bash
# iOS 18 - Many tests fail
xcodebuild test -project iOS18AccessibilityBugRepro.xcodeproj \
  -scheme iOS18AccessibilityBugRepro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'

# iOS 17 - All tests pass
xcodebuild test -project iOS18AccessibilityBugRepro.xcodeproj \
  -scheme iOS18AccessibilityBugRepro \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'
```
