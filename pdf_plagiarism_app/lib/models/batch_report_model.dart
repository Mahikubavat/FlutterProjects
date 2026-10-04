/// Represents an individual student's evaluation in a batch plagiarism report.
class StudentReport {
  final String studentId;
  final String studentName;
  final double maxScore; // Score between 0.0 and 1.0 (or percentage)
  final String topPeerName;
  final bool flagged;

  const StudentReport({
    required this.studentId,
    required this.studentName,
    required this.maxScore,
    required this.topPeerName,
    required this.flagged,
  });

  /// Factory constructor to parse JSON response.
  factory StudentReport.fromJson(Map<String, dynamic> json) {
    final rawMaxScore = json['maxScore'] ?? json['max_score'] ?? 0.0;
    final maxScore = (rawMaxScore as num).toDouble();

    return StudentReport(
      studentId: json['studentId'] as String? ??
          json['student_id'] as String? ??
          '',
      studentName: json['studentName'] as String? ??
          json['student_name'] as String? ??
          'Unknown Student',
      maxScore: maxScore,
      topPeerName: json['topPeerName'] as String? ??
          json['top_peer_name'] as String? ??
          'N/A',
      flagged: json['flagged'] as bool? ?? (maxScore >= 0.40),
    );
  }

  /// Serializes instance to a JSON map.
  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'studentName': studentName,
        'maxScore': maxScore,
        'topPeerName': topPeerName,
        'flagged': flagged,
      };

  @override
  String toString() =>
      'StudentReport(id: $studentId, name: $studentName, maxScore: ${(maxScore * 100).toStringAsFixed(1)}%, topPeer: $topPeerName, flagged: $flagged)';
}

/// Represents the overall batch plagiarism report containing status, progress,
/// and student evaluations.
class BatchReportModel {
  final String batchJobId;
  final String status; // 'QUEUED', 'PROCESSING', 'COMPLETED', 'FAILED'
  final double progress; // 0.0 to 1.0 (or 0.0 to 100.0)
  final List<StudentReport> reports;
  final String? errorMessage;

  const BatchReportModel({
    required this.batchJobId,
    required this.status,
    this.progress = 0.0,
    this.reports = const [],
    this.errorMessage,
  });

  /// True when the batch job has finished computation and results are ready.
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';

  /// True when the batch job encountered a fatal execution error.
  bool get isFailed => status.toUpperCase() == 'FAILED';

  /// True when the batch job is still in progress.
  bool get isProcessing =>
      status.toUpperCase() == 'PROCESSING' ||
      status.toUpperCase() == 'QUEUED' ||
      status.toUpperCase() == 'PREPROCESSING' ||
      status.toUpperCase() == 'COMPUTING';

  /// Factory constructor to parse JSON response.
  factory BatchReportModel.fromJson(Map<String, dynamic> json) {
    final rawReports = json['reports'] as List<dynamic>? ??
        json['studentReports'] as List<dynamic>? ??
        json['students'] as List<dynamic>? ??
        const [];

    final rawProgress =
        json['progress'] ?? json['progressPercent'] ?? json['progress_percent'] ?? 0.0;
    final progress = (rawProgress as num).toDouble();

    return BatchReportModel(
      batchJobId: json['batchJobId'] as String? ??
          json['batch_job_id'] as String? ??
          json['jobId'] as String? ??
          json['id'] as String? ??
          '',
      status: (json['status'] as String? ?? 'QUEUED').toUpperCase(),
      progress: progress,
      reports: rawReports
          .map((item) => StudentReport.fromJson(item as Map<String, dynamic>))
          .toList(),
      errorMessage: json['errorMessage'] as String? ??
          json['error_message'] as String? ??
          json['error'] as String?,
    );
  }

  /// Serializes instance to a JSON map.
  Map<String, dynamic> toJson() => {
        'batchJobId': batchJobId,
        'status': status,
        'progress': progress,
        'reports': reports.map((r) => r.toJson()).toList(),
        if (errorMessage != null) 'errorMessage': errorMessage,
      };

  @override
  String toString() =>
      'BatchReportModel(jobId: $batchJobId, status: $status, progress: ${(progress * 100).toStringAsFixed(1)}%, reports: ${reports.length})';
}
