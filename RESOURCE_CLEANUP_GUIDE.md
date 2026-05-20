# Resource Cleanup & Disposal Best Practices

## Overview

Proper resource management is critical for app stability, memory efficiency, and preventing crashes. This document outlines the resource disposal system implemented across MathswithSD and Mathswithsd_admin apps.

---

## Resource Types & Cleanup Requirements

### 1. **Timers**
- **Type**: `Timer` and `Timer.periodic()`
- **Risk**: If not cancelled, timers continue executing in background, consuming memory
- **Cleanup**: Must call `.cancel()` before app exit or state disposal
- **Example**:
  ```dart
  Timer? _timer;
  
  @override
  void dispose() {
    _timer?.cancel();  // CRITICAL
    super.dispose();
  }
  ```

### 2. **Stream Subscriptions**
- **Type**: `StreamSubscription<T>`
- **Risk**: Memory leak if not cancelled; listener stays alive indefinitely
- **Cleanup**: Must call `.cancel()` in dispose
- **Example**:
  ```dart
  StreamSubscription? _subscription;
  
  void initState() {
    super.initState();
    _subscription = someStream.listen((data) { /* ... */ });
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
  ```

### 3. **Animation Controllers**
- **Type**: `AnimationController`
- **Risk**: Tickers continue running; memory leak if not disposed
- **Cleanup**: Must call `.dispose()` in dispose method
- **Example**:
  ```dart
  AnimationController? _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: Duration(seconds: 1), vsync: this);
  }
  
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
  ```

### 4. **Text Editing Controllers**
- **Type**: `TextEditingController`
- **Risk**: Listeners and resources not cleaned up
- **Cleanup**: Must call `.dispose()` in dispose method
- **Example**:
  ```dart
  TextEditingController? _textCtrl;
  
  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
  }
  
  @override
  void dispose() {
    _textCtrl?.dispose();
    super.dispose();
  }
  ```

### 5. **Tab Controllers**
- **Type**: `TabController`
- **Risk**: Animation tickers don't stop; memory leak
- **Cleanup**: Must call `.dispose()` in dispose method
- **Example**:
  ```dart
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  ```

### 6. **Change Notifiers & Providers**
- **Type**: Custom ChangeNotifier subclasses
- **Risk**: Listeners not notified to cleanup; memory leaks
- **Cleanup**: Must implement proper `dispose()` method
- **Example**:
  ```dart
  class MyProvider with ChangeNotifier {
    @override
    void dispose() {
      // cleanup code here
      super.dispose();
    }
  }
  ```

---

## New Resource Management System

### ResourceManager Class

Central utility for tracking and cleaning up all resources:

```dart
import '../utils/resource_manager.dart';

// Track a resource
ResourceManager().trackTimer(timer);
ResourceManager().trackSubscription(subscription);

// Clean up all tracked resources
await ResourceManager().cleanup();

// Get resource statistics
final stats = ResourceManager().getResourceStats();
print(stats);  // {subscriptions: 0, timers: 1, animationControllers: 2, ...}
```

### ResourceDisposal Mixin (for StatefulWidgets)

Simplifies resource management in State classes:

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> with ResourceDisposal<MyScreen> {
  late Timer _timer;
  
  @override
  void initState() {
    super.initState();
    // Automatically tracked and disposed
    _timer = createSafeTimer(Duration(seconds: 1), (timer) {
      print('Tick');
    });
  }
  
  // dispose() is automatically handled by ResourceDisposal mixin
}
```

### NotifierResourceDisposal Mixin (for Providers)

Simplifies resource management in ChangeNotifier providers:

```dart
class ExamProvider with ChangeNotifier, NotifierResourceDisposal {
  Timer? _timer;
  
  void startExam() {
    _timer = createSafeTimer(Duration(seconds: 1), (timer) {
      // Timer is automatically tracked
      // Will be disposed when provider is disposed
    });
  }
  
  // dispose() automatically handled by mixin
}
```

---

## Implementation Checklist

### For StatefulWidget State Classes

- [ ] Import `resource_manager.dart`
- [ ] Add `ResourceDisposal<T>` mixin to State class
- [ ] Use `createSafeTimer()` instead of `Timer.periodic()`
- [ ] Use `trackSubscription()` for stream subscriptions
- [ ] Use `trackTextController()` for text editors
- [ ] Use `trackAnimationController()` for animations
- [ ] Remove manual dispose calls (handled by mixin)

### For ChangeNotifier Providers

- [ ] Import `resource_manager.dart`
- [ ] Add `NotifierResourceDisposal` mixin to provider
- [ ] Use `createSafeTimer()` instead of `Timer.periodic()`
- [ ] Use `trackSubscription()` for stream subscriptions
- [ ] Remove manual timer cancellation code (handled by mixin)
- [ ] Ensure `super.dispose()` is called

### For Custom Managers/Services

- [ ] Implement proper resource cleanup
- [ ] Track resources with `ResourceManager()`
- [ ] Provide cleanup method if used outside normal lifecycle
- [ ] Document resource requirements

---

## Migration Guide

### Before (Memory Leak Prone)
```dart
class ExamProvider with ChangeNotifier {
  Timer? _timer;
  
  void startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      // Timer logic
      notifyListeners();
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();  // Manual cleanup
    super.dispose();
  }
}
```

### After (Safe & Tracked)
```dart
class ExamProvider with ChangeNotifier, NotifierResourceDisposal {
  Timer? _timer;
  
  void startTimer() {
    _timer = createSafeTimer(Duration(seconds: 1), (_) {
      // Timer logic
      notifyListeners();
    });
  }
  
  // dispose() automatically handled by NotifierResourceDisposal mixin
}
```

---

## Performance Monitoring

### Check Resource Usage

```dart
// At app startup or debugging
final stats = ResourceManager().getResourceStats();
print('Active resources: $stats');

// Output example:
// Active resources: {
//   subscriptions: 2,
//   timers: 1,
//   animationControllers: 3,
//   textControllers: 4,
//   tabControllers: 1
// }
```

### Debug Resource Leaks

1. Enable logging in `ResourceManager`
2. Check stats before and after screen navigation
3. Resources should return to zero when screen closes
4. If not, review that screen's disposal code

---

## Common Pitfalls & Fixes

### Pitfall 1: Forgetting to Dispose Timers
```dart
// ❌ BAD - Timer never cancelled
void _startTimer() {
  Timer.periodic(Duration(seconds: 1), (_) {
    // Continues forever, even after screen closes
  });
}

// ✅ GOOD - With ResourceDisposal mixin
void _startTimer() {
  _timer = createSafeTimer(Duration(seconds: 1), (_) {
    // Automatically cleaned up
  });
}
```

### Pitfall 2: Not Cancelling Stream Subscriptions
```dart
// ❌ BAD - Subscription leaks
@override
void initState() {
  super.initState();
  someStream.listen((data) {
    // Listener stays active forever
  });
}

// ✅ GOOD - With tracking
@override
void initState() {
  super.initState();
  trackSubscription(someStream, (data) {
    // Automatically cancelled on dispose
  });
}
```

### Pitfall 3: Not Disposing Animation Controllers
```dart
// ❌ BAD - Animation leaks
void initState() {
  super.initState();
  _controller = AnimationController(duration: Duration(seconds: 1), vsync: this);
  _controller?.forward();
  // Ticker continues in background
}

// ✅ GOOD - With mixin
void initState() {
  super.initState();
  _controller = trackAnimationController(duration: Duration(seconds: 1));
  _controller?.forward();
  // Automatically cleaned up
}
```

### Pitfall 4: Forgetting super.dispose()
```dart
// ❌ BAD - Mixin cleanup never runs
@override
void dispose() {
  _timer?.cancel();
  // Missing super.dispose() - mixin cleanup skipped
}

// ✅ GOOD
@override
void dispose() {
  _timer?.cancel();
  super.dispose();  // Ensures mixin cleanup runs
}
```

---

## Testing Resource Cleanup

### Unit Test Example
```dart
test('ExamProvider disposes timer properly', () {
  final provider = ExamProvider();
  
  // Check initial state
  expect(ResourceManager().getResourceStats()['timers'], 0);
  
  // Start timer
  provider.startExam();
  expect(ResourceManager().getResourceStats()['timers'], 1);
  
  // Dispose
  provider.dispose();
  expect(ResourceManager().getResourceStats()['timers'], 0);
});
```

### Widget Test Example
```dart
testWidgets('Screen disposes resources on pop', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Navigate to screen
  await tester.tap(find.byType(NavigateButton));
  await tester.pumpAndSettle();
  
  // Check resources active
  var stats = ResourceManager().getResourceStats();
  expect(stats['timers'], greaterThan(0));
  
  // Navigate back
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  
  // Check resources cleaned up
  stats = ResourceManager().getResourceStats();
  expect(stats['timers'], 0);
});
```

---

## Integration Points

### Currently Integrated
- ✅ ExamProvider (both apps) - Uses NotifierResourceDisposal
- ✅ Timer management in exam countdown
- ✅ Resource tracking system created

### Ready for Integration
- [ ] All other Providers
- [ ] All StatefulWidget screens
- [ ] Stream subscriptions throughout codebase
- [ ] Animation controllers in UI widgets

### Recommended Next Steps
1. Update remaining providers to use NotifierResourceDisposal
2. Update high-memory screens to use ResourceDisposal mixin
3. Add resource leak tests
4. Monitor memory usage in production

---

## Debugging Tips

### Enable Debug Logging
```dart
// Add to ResourceManager for debugging
void _logCleanup(String resourceType) {
  if (kDebugMode) {
    debugPrint('[ResourceManager] Cleaned up: $resourceType');
  }
}
```

### Monitor During Development
```dart
// In app lifecycle
Future<void> _checkResourceHealth() async {
  final stats = ResourceManager().getResourceStats();
  if (stats.values.any((count) => count > 10)) {
    debugPrint('⚠️  HIGH RESOURCE COUNT: $stats');
  }
}
```

---

## Reference

- **ResourceManager**: `lib/utils/resource_manager.dart`
- **Implemented in**: 
  - Student App: `lib/utils/resource_manager.dart`
  - Admin App: `lib/utils/resource_manager.dart`
- **Used by**:
  - ExamProvider (both apps)
  - Can be used in any State or ChangeNotifier

---

**Version**: 1.0  
**Status**: Active - Used in ExamProvider  
**Last Updated**: May 2026
