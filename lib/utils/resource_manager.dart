import 'dart:async';
import 'package:flutter/material.dart';

/// Utility class for managing resource lifecycle and cleanup
class ResourceManager {
  static final ResourceManager _instance = ResourceManager._internal();
  
  factory ResourceManager() {
    return _instance;
  }
  
  ResourceManager._internal();

  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];
  final List<AnimationController> _animationControllers = [];
  final List<TextEditingController> _textControllers = [];
  final List<TabController> _tabControllers = [];

  /// Register a stream subscription for tracking
  void trackSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// Register a timer for tracking
  void trackTimer(Timer timer) {
    _timers.add(timer);
  }

  /// Register an AnimationController for tracking
  void trackAnimationController(AnimationController controller) {
    _animationControllers.add(controller);
  }

  /// Register a TextEditingController for tracking
  void trackTextController(TextEditingController controller) {
    _textControllers.add(controller);
  }

  /// Register a TabController for tracking
  void trackTabController(TabController controller) {
    _tabControllers.add(controller);
  }

  /// Unregister a subscription
  void untrackSubscription(StreamSubscription subscription) {
    _subscriptions.remove(subscription);
  }

  /// Unregister a timer
  void untrackTimer(Timer timer) {
    _timers.remove(timer);
  }

  /// Clean up all tracked resources
  Future<void> cleanup() async {
    // Cancel all stream subscriptions
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    // Cancel all timers
    for (final timer in _timers) {
      if (timer.isActive) {
        timer.cancel();
      }
    }
    _timers.clear();

    // Dispose all animation controllers
    for (final controller in _animationControllers) {
      controller.dispose();
    }
    _animationControllers.clear();

    // Dispose all text controllers
    for (final controller in _textControllers) {
      controller.dispose();
    }
    _textControllers.clear();

    // Dispose all tab controllers
    for (final controller in _tabControllers) {
      controller.dispose();
    }
    _tabControllers.clear();
  }

  /// Get statistics about tracked resources
  Map<String, int> getResourceStats() {
    return {
      'subscriptions': _subscriptions.length,
      'timers': _timers.length,
      'animationControllers': _animationControllers.length,
      'textControllers': _textControllers.length,
      'tabControllers': _tabControllers.length,
    };
  }
}

/// Extension on Timer for automatic cleanup
extension TimerExtension on Timer {
  /// Create a safe timer that automatically tracks with ResourceManager
  static Timer safePeriodicTimer(
    Duration duration,
    void Function(Timer) callback,
  ) {
    final timer = Timer.periodic(duration, callback);
    ResourceManager().trackTimer(timer);
    return timer;
  }

  /// Create a safe delayed timer
  static Timer safeTimer(
    Duration duration,
    void Function() callback,
  ) {
    final timer = Timer(duration, callback);
    ResourceManager().trackTimer(timer);
    return timer;
  }
}

/// Extension on StreamSubscription for automatic cleanup
extension StreamSubscriptionExtension<T> on StreamSubscription<T> {
  /// Register this subscription with ResourceManager
  StreamSubscription<T> trackResource() {
    ResourceManager().trackSubscription(this);
    return this;
  }

  /// Cancel and untrack
  Future<void> cancelAndUntrack() async {
    ResourceManager().untrackSubscription(this);
    await cancel();
  }
}

/// Mixin for easy resource disposal in State classes
mixin ResourceDisposal<T extends StatefulWidget> on State<T> {
  final ResourceManager _resourceManager = ResourceManager();

  /// Create a safe timer that's automatically tracked
  Timer createSafeTimer(Duration duration, void Function(Timer) callback) {
    final timer = Timer.periodic(duration, callback);
    _resourceManager.trackTimer(timer);
    return timer;
  }

  /// Create a tracked stream subscription
  StreamSubscription<S> trackSubscription<S>(Stream<S> stream, void Function(S) onData) {
    return stream.listen(onData).trackResource();
  }

  /// Track a text controller
  TextEditingController trackTextController([String initialValue = '']) {
    final controller = TextEditingController(text: initialValue);
    _resourceManager.trackTextController(controller);
    return controller;
  }

  /// Track an animation controller
  AnimationController trackAnimationController({
    required Duration duration,
    double lowerBound = 0.0,
    double upperBound = 1.0,
    TickerProvider? vsync,
  }) {
    final controller = AnimationController(
      duration: duration,
      lowerBound: lowerBound,
      upperBound: upperBound,
      vsync: vsync ?? this,
    );
    _resourceManager.trackAnimationController(controller);
    return controller;
  }

  @override
  void dispose() {
    _resourceManager.cleanup();
    super.dispose();
  }
}

/// Mixin for easy resource disposal in ChangeNotifier (Providers)
mixin NotifierResourceDisposal on ChangeNotifier {
  final ResourceManager _resourceManager = ResourceManager();
  final List<Timer> _localTimers = [];

  /// Create a safe timer with automatic tracking
  Timer createSafeTimer(Duration duration, void Function(Timer) callback) {
    final timer = Timer.periodic(duration, callback);
    _localTimers.add(timer);
    _resourceManager.trackTimer(timer);
    return timer;
  }

  /// Create a tracked stream subscription
  StreamSubscription<S> trackSubscription<S>(Stream<S> stream, void Function(S) onData) {
    return stream.listen(onData).trackResource();
  }

  @override
  void dispose() {
    // Cancel all local timers first
    for (final timer in _localTimers) {
      if (timer.isActive) {
        timer.cancel();
      }
    }
    _localTimers.clear();

    // Clean up via ResourceManager
    _resourceManager.cleanup();
    super.dispose();
  }
}
