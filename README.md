# UIAccessibility.convertToScreenCoordinates mutates input UIBezierPath on iOS 18+

## Summary

`UIAccessibility.convertToScreenCoordinates(_:in:)` mutates the input `UIBezierPath` in-place on iOS 18 and later. This violates the documented API contract which states it **"returns a new path object with the results"**.

> "Converts the specified path object to screen coordinates and **returns a new path object** with the results."
> — [Apple Developer Documentation](https://developer.apple.com/documentation/uikit/uiaccessibility/1615139-converttoscreencoordinates)

## Environment

- iOS 18.0+ (tested on 18.5 and 26.1)
- Does NOT occur on iOS 17.5 and earlier
- Xcode 16.4 / Xcode 26.1

## Bug is Path-Type Specific

The bug only affects certain path types:

| Path Type | iOS 18 Behavior |
|-----------|-----------------|
| `UIBezierPath(rect:)` | ✅ Works correctly |
| `UIBezierPath(ovalIn:)` | ✅ Works correctly |
| `UIBezierPath(arcCenter:...)` | ✅ Works correctly |
| `UIBezierPath(roundedRect:cornerRadius:)` | ❌ **BUG** - coordinates accumulate |
| Custom path with `addLine` | ❌ **BUG** - coordinates accumulate |
| Custom path with `addQuadCurve` | ❌ **BUG** - coordinates accumulate |
| Custom path with `addCurve` | ❌ **BUG** - coordinates accumulate |
| Path with only `move(to:)` | ❌ **BUG** - coordinates accumulate |

**Pattern**: Paths built with explicit path elements (`move`, `addLine`, `addQuadCurve`, `addCurve`) are affected, while convenience initializers (`rect`, `ovalIn`, `arcCenter`) are not.

## Steps to Reproduce

1. Create a `UIView` subclass that stores a `UIBezierPath` in local coordinates
2. Override `accessibilityPath` to convert the stored path using `UIAccessibility.convertToScreenCoordinates`
3. Use a path type that triggers the bug (e.g., `roundedRect` or custom path with `addLine`)
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
```

Run the unit tests:

```bash
# iOS 18 - Some tests FAIL
xcodebuild test -project iOS18AccessibilityBugRepro.xcodeproj \
  -scheme iOS18AccessibilityBugRepro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:iOS18AccessibilityBugReproTests/AccessibilityPathMutationTests

# iOS 17 - All tests PASS  
xcodebuild test -project iOS18AccessibilityBugRepro.xcodeproj \
  -scheme iOS18AccessibilityBugRepro \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  -only-testing:iOS18AccessibilityBugReproTests/AccessibilityPathMutationTests
```

## Expected Results

Per the [documented behavior](https://developer.apple.com/documentation/uikit/uiaccessibility/1615139-converttoscreencoordinates), the method should return a new path object. The input path should not be modified.

Each read of `accessibilityPath` returns the same screen coordinates:

```
Read 1: origin=(100.0, 200.0)
Read 2: origin=(100.0, 200.0)
Read 3: origin=(100.0, 200.0)
```

## Actual Results

On iOS 18+ with affected path types, the input path is mutated in-place. Coordinates accumulate with each call:

```
Read 1: origin=(100.0, 200.0)   ← correct
Read 2: origin=(200.0, 400.0)   ← doubled
Read 3: origin=(300.0, 600.0)   ← tripled
```

## Regression

| iOS Version | Result |
|-------------|--------|
| iOS 17.5    | ✅ All tests pass |
| iOS 18.5    | ❌ Tests for affected path types fail |
| iOS 26.1    | ❌ Tests for affected path types fail |

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
