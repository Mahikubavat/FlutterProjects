import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/batch_report_model.dart';
import '../services/batch_repository.dart';

// ============================================================================
// BATCH STATES
// ============================================================================

/// Sealed base class representing all batch evaluation UI states.
sealed class BatchState {
  const BatchState();
}

/// Initial idle state before any batch evaluation is started.
class BatchInitial extends BatchState {
  const BatchInitial();

  @override
  String toString() => 'BatchInitial()';
}

/// Loading state tracking execution progress (0.0 to 1.0 or 0 to 100).
class BatchLoading extends BatchState {
  final double progress;

  const BatchLoading({this.progress = 0.0});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchLoading &&
          runtimeType == other.runtimeType &&
          progress == other.progress;

  @override
  int get hashCode => progress.hashCode;

  @override
  String toString() =>
      'BatchLoading(progress: ${(progress * 100).toStringAsFixed(1)}%)';
}

/// Success state holding the completed [BatchReportModel].
class BatchSuccess extends BatchState {
  final BatchReportModel report;

  const BatchSuccess(this.report);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchSuccess &&
          runtimeType == other.runtimeType &&
          report == other.report;

  @override
  int get hashCode => report.hashCode;

  @override
  String toString() => 'BatchSuccess(jobId: ${report.batchJobId}, students: ${report.reports.length})';
}

/// Error state containing a user-facing failure message.
class BatchError extends BatchState {
  final String message;

  const BatchError(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'BatchError(message: $message)';
}

// ============================================================================
// BASE CUBIT / STATE NOTIFIER ABSTRACTION
// ============================================================================

/// Lightweight Cubit base implementing Flutter's [ValueNotifier].
/// Emits state updates, integrates seamlessly with [ValueListenableBuilder],
/// [Provider], or [BlocBuilder], and requires no heavy external runtime dependencies.
abstract class Cubit<State> extends ValueNotifier<State> {
  Cubit(super.initialState);

  /// Current state of the Cubit.
  State get state => value;

  bool _isClosed = false;
  bool get isClosed => _isClosed;

  /// Emits a new [state] to all active listeners if the Cubit is not closed.
  @protected
  void emit(State newState) {
    if (_isClosed) return;
    if (value != newState) {
      value = newState;
    }
  }

  /// Closes the Cubit and releases resources.
  @mustCallSuper
  void close() {
    _isClosed = true;
    dispose();
  }
}

// ============================================================================
// BATCH CUBIT / STATE NOTIFIER IMPLEMENTATION
// ============================================================================

/// State management class managing the lifecycle, triggering, and 2-second
/// polling of batch plagiarism evaluations.
class BatchCubit extends Cubit<BatchState> {
  final BatchRepository _repository;
  Timer? _pollingTimer;
  String? _currentJobId;
  int _consecutivePollErrors = 0;

  /// Maximum consecutive network poll failures before aborting to [BatchError].
  static const int maxConsecutivePollErrors = 3;

  /// Maximum polling duration (default: 5 minutes / 150 attempts @ 2s interval).
  static const int defaultMaxPollAttempts = 150;

  BatchCubit({required BatchRepository repository})
      : _repository = repository,
        super(const BatchInitial());

  /// Currently active batch job ID (if any).
  String? get currentJobId => _currentJobId;

  /// Triggers a new batch evaluation job and starts polling every 2 seconds.
  Future<void> startBatchEvaluation({
    required List<String> userIds,
    required String assignmentTag,
    Duration pollingInterval = const Duration(seconds: 2),
    int maxPollAttempts = defaultMaxPollAttempts,
  }) async {
    _stopPolling();
    _consecutivePollErrors = 0;
    emit(const BatchLoading(progress: 0.0));

    try {
      final jobId = await _repository.startBatchJob(
        userIds: userIds,
        assignmentTag: assignmentTag,
      );

      _currentJobId = jobId;
      if (isClosed) return;

      int attempts = 0;

      // Start periodic 2-second polling
      _pollingTimer = Timer.periodic(pollingInterval, (timer) async {
        attempts++;

        if (attempts > maxPollAttempts) {
          _stopPolling();
          emit(const BatchError('Evaluation request timed out after 5 minutes.'));
          return;
        }

        await _pollResults(jobId);
      });
    } catch (e) {
      emit(BatchError('Failed to initiate batch evaluation: $e'));
    }
  }

  /// Internal polling routine executed every [pollingInterval].
  Future<void> _pollResults(String jobId) async {
    try {
      final report = await _repository.fetchBatchResults(jobId);

      if (isClosed) {
        _stopPolling();
        return;
      }

      _consecutivePollErrors = 0; // Reset network error count on successful poll

      if (report.isCompleted) {
        _stopPolling();
        emit(BatchSuccess(report));
      } else if (report.isFailed) {
        _stopPolling();
        emit(BatchError(report.errorMessage ?? 'Batch evaluation failed on server.'));
      } else {
        // Still processing: update progress fraction
        emit(BatchLoading(progress: report.progress));
      }
    } catch (e) {
      _consecutivePollErrors++;
      if (_consecutivePollErrors >= maxConsecutivePollErrors) {
        _stopPolling();
        emit(BatchError('Connection lost while polling batch results: $e'));
      }
    }
  }

  /// Sets loading state and progress directly for local offline evaluation.
  void setLoading(double progress) {
    _stopPolling();
    emit(BatchLoading(progress: progress.clamp(0.0, 1.0)));
  }

  /// Sets error state manually.
  void setError(String message) {
    _stopPolling();
    emit(BatchError(message));
  }

  /// Sets a completed report directly (used for local simulations/testing).
  void setSuccessReport(BatchReportModel report) {
    _stopPolling();
    emit(BatchSuccess(report));
  }

  /// Manually cancels any active polling timer.
  void cancelEvaluation() {
    _stopPolling();
    emit(const BatchInitial());
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void close() {
    _stopPolling();
    super.close();
  }
}
