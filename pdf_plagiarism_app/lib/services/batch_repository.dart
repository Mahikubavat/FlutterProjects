import '../models/batch_report_model.dart';
import 'batch_api_service.dart';

/// Repository interface for batch evaluation operations.
abstract class BatchRepository {
  Future<String> startBatchJob({
    required List<String> userIds,
    required String assignmentTag,
  });

  Future<BatchReportModel> fetchBatchResults(String batchJobId);
}

/// Concrete implementation of [BatchRepository] delegating to [IBatchApiService].
class BatchRepositoryImpl implements BatchRepository {
  final IBatchApiService _apiService;

  BatchRepositoryImpl({required IBatchApiService apiService})
      : _apiService = apiService;

  @override
  Future<String> startBatchJob({
    required List<String> userIds,
    required String assignmentTag,
  }) {
    return _apiService.startBatchJob(
      userIds: userIds,
      assignmentTag: assignmentTag,
    );
  }

  @override
  Future<BatchReportModel> fetchBatchResults(String batchJobId) {
    return _apiService.fetchBatchResults(batchJobId);
  }
}
