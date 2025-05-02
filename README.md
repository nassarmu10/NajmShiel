# NajmShiel


A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

#### Publish to App Store

https://www.youtube.com/watch?v=0zgDF81ZLrQ&ab_channel=HeyFlutter%E2%80%A4com

sometimes you need to:
1. clean iOS build: 

```
cd ios && rm -rf Pods Podfile.lock && pod cache clean --all
```

2. run ``` pod install ```

3. Clean and reinstall pods:
```
rm -rf Pods Podfile.lock && pod install
```