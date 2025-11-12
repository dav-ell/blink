import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/job.dart';
import '../core/constants.dart';
import '../repositories/chat_repository.dart';

/// Provider for managing job polling state
/// 
/// Handles polling for async job status with exponential backoff.
/// Manages multiple jobs simultaneously.
class JobPollingProvider with ChangeNotifier {
  final ChatRepository _repository;
  final Map<String, Timer> _activePollers = {};
  final Map<String, int> _pollAttempts = {};
  
  // Callbacks for job status changes
  final Map<String, Function(Job)> _onJobUpdate = {};
  final Map<String, Function(Job)> _onJobComplete = {};
  final Map<String, Function(Job, String)> _onJobFailed = {};
  
  JobPollingProvider({ChatRepository? repository})
      : _repository = repository ?? ChatRepository();
  
  /// Get count of active polling jobs
  int get activeJobCount => _activePollers.length;
  
  /// Get list of active job IDs
  List<String> get activeJobIds => List.from(_activePollers.keys);
  
  /// Check if a job is being polled
  bool isPolling(String jobId) => _activePollers.containsKey(jobId);
  
  /// Start polling a job
  Future<void> startPolling(
    String jobId, {
    required Function(Job) onUpdate,
    required Function(Job) onComplete,
    required Function(Job, String) onFailed,
  }) async {
    // Stop existing poller if any
    stopPolling(jobId);
    
    // Register callbacks
    _onJobUpdate[jobId] = onUpdate;
    _onJobComplete[jobId] = onComplete;
    _onJobFailed[jobId] = onFailed;
    
    // Reset attempt counter
    _pollAttempts[jobId] = 0;
    
    notifyListeners();
    
    // Start polling immediately
    await _pollJob(jobId);
  }
  
  /// Stop polling a specific job
  void stopPolling(String jobId) {
    _activePollers[jobId]?.cancel();
    _activePollers.remove(jobId);
    _pollAttempts.remove(jobId);
    _onJobUpdate.remove(jobId);
    _onJobComplete.remove(jobId);
    _onJobFailed.remove(jobId);
    notifyListeners();
  }
  
  /// Stop all active pollers
  void stopAll() {
    final jobIds = List<String>.from(_activePollers.keys);
    for (final jobId in jobIds) {
      stopPolling(jobId);
    }
  }
  
  /// Poll a job once
  Future<void> _pollJob(String jobId) async {
    try {
      final result = await _repository.getJobDetails(jobId);
      
      await result.when(
        success: (job) async {
          // Call update callback
          _onJobUpdate[jobId]?.call(job);
          
          // Check if job is complete
          if (job.isCompleted) {
            _onJobComplete[jobId]?.call(job);
            stopPolling(jobId);
            return;
          }
          
          // Check if job failed
          if (job.isFailed) {
            _onJobFailed[jobId]?.call(job, job.error ?? 'Unknown error');
            stopPolling(jobId);
            return;
          }
          
          // Check if job was cancelled
          if (job.isCancelled) {
            _onJobFailed[jobId]?.call(job, 'Job was cancelled');
            stopPolling(jobId);
            return;
          }
          
          // Schedule next poll with backoff
          _scheduleNextPoll(jobId);
        },
        failure: (error) {
          // On error, retry with backoff
          _scheduleNextPoll(jobId);
        },
      );
    } catch (e) {
      // On error, retry with backoff
      _scheduleNextPoll(jobId);
    }
  }
  
  /// Schedule next poll with exponential backoff
  void _scheduleNextPoll(String jobId) {
    final attempts = _pollAttempts[jobId] ?? 0;
    _pollAttempts[jobId] = attempts + 1;
    
    // Calculate delay with exponential backoff
    // 1s, 2s, 5s, 5s, 5s, ...
    final Duration delay;
    if (attempts == 0) {
      delay = AppConstants.pollIntervalShort;
    } else if (attempts == 1) {
      delay = AppConstants.pollIntervalMedium;
    } else {
      delay = AppConstants.pollIntervalLong;
    }
    
    // Schedule next poll
    _activePollers[jobId] = Timer(delay, () => _pollJob(jobId));
  }
  
  @override
  void dispose() {
    stopAll();
    _repository.dispose();
    super.dispose();
  }
}

