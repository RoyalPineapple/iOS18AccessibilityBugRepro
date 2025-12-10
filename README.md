# UIAccessibility.convertToScreenCoordinates Path Mutation Bug

## Summary

In iOS 18+, `UIAccessibility.convertToScreenCoordinates(_:in:)` uses a global accumulation counter that causes returned path coordinates to drift on repeated calls. The function creates new output paths (as documented) but calculates coordinates using internal state that accumulates N× the screen offset without resetting between calls.

**Observed in:** iOS 18.0 through iOS 26.1
**Last working version:** iOS 17.5

## Expected Behavior

Per Apple's documentation, `convertToScreenCoordinates(_:in:)` should "return a new path object" with converted coordinates. A standard pattern for implementing `accessibilityPath` is:

```swift
override var accessibilityPath: UIBezierPath? {
    get {
        guard let path = relativePath else { return nil }
        return UIAccessibility.convertToScreenCoordinates(path, in: self)
    }
}
```

Starting in iOS 18, this API uses corrupted internal state when calculating the returned path's coordinates, causing accumulation errors on repeated calls.

## Minimal Reproduction

```swift
// 1. Implement accessibilityPath using the documented pattern
class AccessibilityPathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        guard let path = relativePath else { return nil }
        return UIAccessibility.convertToScreenCoordinates(path, in: self)
    }
}

// 2. Add to visible window at position (100, 200)
let view = AccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
view.relativePath = path
window.addSubview(view)
window.makeKeyAndVisible()

// 3. Access the path multiple times
let first = view.accessibilityPath   // Returns path at (100, 200) ✓
let second = view.accessibilityPath  // Returns path at (200, 400) ✗ Wrong!
let third = view.accessibilityPath   // Returns path at (300, 600) ✗ Accumulating!

// 4. The input path remains unchanged
print(path.bounds.origin)  // Still (0, 0) - input never modified
print(first.bounds.origin) // (100, 200) - correct
print(second.bounds.origin) // (200, 400) - 2× screen offset
print(third.bounds.origin)  // (300, 600) - 3× screen offset
```

**Expected:** Returns a new path with screen coordinates (100, 200) on each call; input path unchanged.
**Actual:** Returns new paths with cumulative coordinate errors: 1st call correct, 2nd call has 2× offset, 3rd call has 3× offset. Input path remains unchanged (the bug is in output generation, not input mutation).

### Visual Comparison

Screenshots generated with [AccessibilitySnapshot](https://github.com/cashapp/AccessibilitySnapshot) showing VoiceOver focus outlines:

| iOS 17.5 (Working) | iOS 18+ (Bug) |
|-------------------|---------------|
| ![iOS 17 Reference](testAccessibilityPaths_17_5_393x852@3x.png) | ![iOS 18 Bug](testAccessibilityPaths_18_5_402x874@3x.png) |
| All VoiceOver outlines correctly aligned with their views | **Cyan** outline drifted right; **Yellow** and **Purple** outlines completely off-screen.<br/>**Magenta**, **Green**, and **Blue** outlines remain correctly aligned (unaffected path types). |

**Affected path types:**
- **Cyan:** `UIBezierPath(roundedRect:cornerRadius:)` - visibly drifted
- **Yellow:** `UIBezierPath(cgPath:)` with quadCurve - off-screen
- **Purple:** `UIBezierPath(cgPath:)` with lines - off-screen

**Unaffected path types:**
- **Magenta:** `UIBezierPath(rect:)` - stable
- **Green:** `UIBezierPath(arcCenter:...)` - stable
- **Blue:** `UIBezierPath(ovalIn:)` - stable

## Version History

| iOS Version | Status |
|-------------|--------|
| iOS 17.5 | Works as documented |
| iOS 18.0+ | Path mutation occurs |
| iOS 26.1 | Still present |

## Technical Details

**Root cause:** The function uses a **global accumulation counter** that increments on every call and applies N× the screen offset to the returned path coordinates. The input path is never modified - the bug is entirely in how the function calculates the output path's coordinates.

**Accumulation pattern:**
```
returned_coordinates = original + (N × screenOffset)

where:
  N = global call counter (1, 2, 3, ...) shared across ALL views/paths
  screenOffset = view.convert(CGPoint.zero, to: nil)
```

**Key findings from investigation tests:**
- ✓ Input path remains unchanged (same object, bounds, and CGPath pointer)
- ✓ Each call returns a NEW path object (different CGPath pointers)
- ✓ Counter is GLOBAL, not per-view (multiple views share the same counter)
- ✓ Creating fresh path/view objects each time doesn't help (counter still accumulates)
- ✓ Counter resets when path object identity changes (why `path?.copy()` works)
- ✓ Counter does NOT reset when view moves (only when path changes)

**Trigger conditions** (all required):
- Most path types (see Visual Comparison section for specifics)
- View is in a key, visible window
- Called from within `accessibilityPath` getter
- Multiple calls to the function (counter accumulates)

**Unaffected paths:** `UIBezierPath(rect:)`, `UIBezierPath(ovalIn:)`, and `UIBezierPath(arcCenter:...)` avoid the bug (likely use optimized internal representations). All other tested path types including `roundedRect` and `cgPath` constructions with explicit elements are affected.

## Workaround

Copy the path before conversion to create a new path object, which resets the internal counter:

```swift
override var accessibilityPath: UIBezierPath? {
    get {
        guard let path = relativePath?.copy() as? UIBezierPath else { return nil }
        return UIAccessibility.convertToScreenCoordinates(path, in: self)
    }
    set { super.accessibilityPath = newValue }
}
```

**Why this works:** The global counter is tied to path object identity. Creating a new path object via `copy()` resets the counter to start from 1, ensuring the first (and only) call with that path object produces correct coordinates.

## Running the Tests

The test suite in `iOSAccessibilityPathBugTests/PathMutationDemonstration.swift` demonstrates the bug patterns and verifies the workaround:

```bash
xcodebuild test -project iOSAccessibilityPathBug.xcodeproj \
  -scheme BugDemonstrationTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'
```
