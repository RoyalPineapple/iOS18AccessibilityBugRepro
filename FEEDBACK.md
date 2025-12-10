# Apple Feedback: UIAccessibility.convertToScreenCoordinates Mutates Input Path

**Feedback Type:** Bug Report
**Area:** UIAccessibility API
**Reproducible:** Always

## Summary

`UIAccessibility.convertToScreenCoordinates(_:in:)` uses a global accumulation counter that causes returned path coordinates to drift on repeated calls. This regression was introduced in iOS 18.0 and causes VoiceOver focus outlines to drift away from their intended positions. The function correctly creates new output paths as documented, but calculates their coordinates using corrupted internal state that accumulates N× the screen offset without resetting between calls.

## Description

The `UIAccessibility.convertToScreenCoordinates(_:in:)` API is documented to "return a new path object" with coordinates converted to screen space. Starting in iOS 18.0, the function uses a global accumulation counter that increments on every call, causing returned coordinates to be incorrect: the 1st call returns correct coordinates, the 2nd call returns 2× the screen offset, the 3rd call returns 3× the screen offset, and so on. The input path parameter remains unchanged - the bug is entirely in how output coordinates are calculated.

This breaks the standard implementation pattern for `accessibilityPath` where a single relative path is converted on each access. When a view's `accessibilityPath` getter is accessed multiple times (as happens during normal VoiceOver usage), the returned coordinates drift further from the correct position with each access. This manifests visually as VoiceOver focus outlines that are incorrectly positioned or completely off-screen.

## Steps to Reproduce

1. Create a UIView subclass that implements `accessibilityPath` using the documented pattern:

```swift
class AccessibilityPathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        guard let path = relativePath else { return nil }
        return UIAccessibility.convertToScreenCoordinates(path, in: self)
    }
}
```

2. Create a view instance with a `roundedRect` path and add it to a key, visible window:

```swift
let view = AccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
view.relativePath = path
window.addSubview(view)
window.makeKeyAndVisible()
```

3. Access `view.accessibilityPath` multiple times:

```swift
let first = view.accessibilityPath   // bounds.origin.x = 100 ✓
let second = view.accessibilityPath  // bounds.origin.x = 200 ✗ (2× offset)
let third = view.accessibilityPath   // bounds.origin.x = 300 ✗ (3× offset)

// Input path remains unchanged - bug is in output calculation
print(path.bounds.origin)            // Still (0, 0)
print(first.bounds.origin)           // (100, 200) - correct
print(second.bounds.origin)          // (200, 400) - wrong!
print(third.bounds.origin)           // (300, 600) - wrong!
```

## Expected Results

- Each call to `convertToScreenCoordinates(_:in:)` should return a new path with correct screen coordinates (100, 200)
- The input path parameter should remain unchanged at (0, 0)
- Multiple accesses to `accessibilityPath` should return consistent, correct coordinates
- VoiceOver focus outlines should align correctly with their views

## Actual Results

- Each call to `convertToScreenCoordinates(_:in:)` returns a new path (as documented) BUT with incorrect coordinates
- The input path remains unchanged (correct) but returned paths have cumulative errors: 1st=(100,200) ✓, 2nd=(200,400) ✗, 3rd=(300,600) ✗
- Coordinates follow pattern: `returned_coordinates = original + (N × screenOffset)` where N is a global call counter
- Multiple accesses to `accessibilityPath` return increasingly incorrect coordinates
- VoiceOver focus outlines drift away from their views or appear off-screen

**Root cause:** Global accumulation counter that:
- Increments on every call to the function (across ALL views/paths)
- Is tied to path object identity (resets when path object changes)
- Does NOT reset when view moves or when creating fresh view instances
- Applies N× the screen offset to output coordinates

## Configuration

**Affected Versions:**
- iOS 18.0 through iOS 26.1 (latest tested)
- Reproduced on both iOS Simulator and physical devices

**Last Working Version:**
- iOS 17.5

**Affected Path Types:**
- `UIBezierPath(roundedRect:cornerRadius:)`
- `UIBezierPath(cgPath:)` with explicit path elements (lines, curves)
- Most path construction methods

**Unaffected Path Types:**
- `UIBezierPath(rect:)`
- `UIBezierPath(ovalIn:)`
- `UIBezierPath(arcCenter:radius:startAngle:endAngle:clockwise:)`

**Trigger Conditions** (all required):
- View must be in a key, visible window hierarchy
- API called from within `accessibilityPath` getter
- Multiple calls to the function (counter accumulates globally)
- Affected path types (see below)

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

**Why this works:** The global accumulation counter is tied to path object identity. Creating a new path object via `copy()` resets the counter to 1, ensuring each call with the copied path produces correct coordinates (since it's only called once per copy).

## Sample Project

A complete sample project demonstrating this issue is attached or available at:
https://github.com/RoyalPineapple/iOSAccessibilityPathBug

The project includes:
- Unit tests documenting the bug across different path types
- Before/after screenshots showing the visual impact
- Tests verifying the workaround

To run the demonstration tests:
```bash
xcodebuild test -project iOSAccessibilityPathBug.xcodeproj \
  -scheme BugDemonstrationTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'
```

## Additional Notes

This regression has significant impact on apps using custom accessibility paths, as VoiceOver users will encounter incorrectly positioned focus indicators that do not align with the actual interactive elements. The issue occurs in normal VoiceOver usage as the system queries `accessibilityPath` multiple times during navigation.

**Key technical findings from investigation:**
- The input path is NEVER mutated (confirmed via object identity, bounds checks, and CGPath pointer tracking)
- Each call returns a NEW CGPath object (confirmed via distinct pointer addresses)
- The counter is GLOBAL across all views and paths (confirmed via interleaved multi-view tests)
- Creating fresh path/view instances each time does NOT prevent accumulation (counter is global)
- The counter resets when path object identity changes (confirmed: setting new path resets counter)
- The counter does NOT reset when view moves (only path object change triggers reset)

These findings conclusively demonstrate the bug is in the function's internal coordinate calculation logic, not in path mutation as initially suspected.
