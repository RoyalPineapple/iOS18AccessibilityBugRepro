# UIAccessibility.convertToScreenCoordinates mutates input UIBezierPath on iOS 18+

## Summary

`UIAccessibility.convertToScreenCoordinates(_:in:)` mutates the input `UIBezierPath` in-place on iOS 18 and later, instead of returning a new path with converted coordinates. This is a regression from iOS 17 behavior and breaks any code that stores a relative path and converts it on demand.

## Environment

- iOS 18.0+ (tested on 18.5 and 26.1)
- Does NOT occur on iOS 17.5 and earlier
- Xcode 16.4 / Xcode 26.1

## Description

When calling `UIAccessibility.convertToScreenCoordinates(path, in: view)`, the API is expected to return a new `UIBezierPath` with coordinates converted to screen space, leaving the input path unchanged.

On iOS 18+, the input path is mutated in-place. Each subsequent call adds the view's screen position to the path again, causing coordinates to accumulate.

This breaks the common pattern of storing a path in local coordinates and converting it in the `accessibilityPath` getter:

```swift
class CustomView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            // iOS 18 BUG: This mutates `relativePath` in-place!
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { super.accessibilityPath = newValue }
    }
}
```

## Steps to Reproduce

1. Create a UIView subclass that stores a `UIBezierPath` in local coordinates
2. Override `accessibilityPath` to convert the stored path using `UIAccessibility.convertToScreenCoordinates`
3. Read `accessibilityPath` multiple times

## Expected Results

Each read of `accessibilityPath` should return the same screen coordinates:

```
Read 1: origin=(100.0, 200.0)
Read 2: origin=(100.0, 200.0)
Read 3: origin=(100.0, 200.0)
Read 4: origin=(100.0, 200.0)
Read 5: origin=(100.0, 200.0)
```

## Actual Results

On iOS 18+, coordinates accumulate with each read:

```
Read 1: origin=(100.0, 200.0)   ← correct
Read 2: origin=(200.0, 400.0)   ← doubled!
Read 3: origin=(300.0, 600.0)   ← tripled!
Read 4: origin=(400.0, 800.0)   ← quadrupled!
Read 5: origin=(500.0, 1000.0)  ← 5x!
```

## Regression

- **iOS 17.5**: Works correctly, input path is not mutated
- **iOS 18.5**: Bug present, input path is mutated
- **iOS 26.1**: Bug still present, not fixed

## Impact

This bug affects:
- Apps with custom accessible controls using `accessibilityPath`
- Accessibility snapshot testing libraries
- Any code where `accessibilityPath` is read multiple times (VoiceOver, Accessibility Inspector, UI testing)

The bug causes accessibility paths to drift further from their intended position with each access, making VoiceOver focus regions increasingly incorrect.

## Workaround

Copy the path before calling `convertToScreenCoordinates`:

```swift
override var accessibilityPath: UIBezierPath? {
    get {
        guard let path = relativePath else { return nil }
        let pathCopy = path.copy() as! UIBezierPath  // Workaround
        return UIAccessibility.convertToScreenCoordinates(pathCopy, in: self)
    }
    set { super.accessibilityPath = newValue }
}
```

## Sample Project

A complete reproduction project with unit tests is available:
https://github.com/RoyalPineapple/iOS18AccessibilityBugRepro

Run tests on iOS 17.5 (pass) vs iOS 18.5+ (fail) to verify the regression.
