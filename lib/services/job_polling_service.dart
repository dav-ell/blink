import 'dart:async';
import '../models/job.dart';
import 'cursor_agent_service.dart';

/// Service for polling job status with exponential backoff
class JobPollingService {
  final CursorAgentService _agentService;
  final Map<String, Timer> _activePollers = {};
  final Map<String, int> _pollAttempts = {};
  
  // Callbacks for job status changes
  final Map<String, Function(Job)> _onJobUpdate = {};
  final Map<String, Function(Job)> _onJobComplete = {};
  final Map<String, Function(Job, String)> _onJobFailed = {};

  JobPollingService({CursorAgentService? agentService})
      : _agentService = agentService ?? CursorAgentService();

  /// Start polling a job with exponential backoff
  /// 
  /// Polling intervals: 1s, 2s, 5s, 5s, ...
  void startPolling(
    String jobId, {
    Function(Job)? onUpdate,
    Function(Job)? onComplete,
    Function(Job, String)? onFailed,
  }) {
    // Stop existing poller if any
    stopPolling(jobId);
    
    // Register callbacks
    if (onUpdate != null) _onJobUpdate[jobId] = onUpdate;
    if (onComplete != null) _onJobComplete[jobId] = onComplete;
    if (onFailed != null) _onJobFailed[jobId] = onFailed;
    
    // Reset attempt counter
    _pollAttempts[jobId] = 0;
    
    // Start polling immediately
    _pollJob(jobId);
  }

  /// Stop polling a job
  void stopPolling(String jobId) {
    _activePollers[jobId]?.cancel();
    _activePollers.remove(jobId);
    _pollAttempts.remove(jobId);
    _onJobUpdate.remove(jobId);
    _onJobComplete.remove(jobId);
    _onJobFailed.remove(jobId);
  }

  /// Stop all active pollers
  void stopAll() {
    final jobIds = List<String>.from(_activePollers.keys);
    for (final jobId in jobIds) {
      stopPolling(jobId);
    }
  }

  /// Check if a job is being polled
  bool isPolling(String jobId) {
    return _activePollers.containsKey(jobId);
  }

  /// Get all active job IDs being polled
  List<String> get activeJobIds => List.from(_activePollers.keys);

  Future<void> _pollJob(String jobId) async {
    try {
      // Fetch job details
      final job = await _agentService.getJobDetails(jobId);
      
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
      
    } catch (e) {
      // On error, retry with backoff
      _scheduleNextPoll(jobId);
    }
  }

  void _scheduleNextPoll(String jobId) {
    final attempts = _pollAttempts[jobId] ?? 0;
    _pollAttempts[jobId] = attempts + 1;
    
    // Calculate delay with exponential backoff
    // 1s, 2s, 5s, 5s, 5s, ...
    final Duration delay;
    if (attempts == 0) {
      delay = const Duration(seconds: 1);
    } else if (attempts == 1) {
      delay = const Duration(seconds: 2);
    } else {
      delay = const Duration(seconds: 5);
    }
    
    // Schedule next poll
    _activePollers[jobId] = Timer(delay, () => _pollJob(jobId));
  }

  /// Manually trigger a poll for a specific job (useful for pull-to-refresh)
  Future<Job?> pollOnce(String jobId) async {
    try {
      return await _agentService.getJobDetails(jobId);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    stopAll();
    _agentService.dispose();
  }
}

