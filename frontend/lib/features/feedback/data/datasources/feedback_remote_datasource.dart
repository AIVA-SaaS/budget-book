import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/feedback/data/models/feedback_models.dart';

abstract class FeedbackRemoteDataSource {
  // User endpoints
  Future<List<FeedbackPostModel>> getFeedbacks();
  Future<FeedbackPostModel> createFeedback(Map<String, dynamic> data);
  Future<FeedbackPostModel> getFeedbackDetail(String id);
  Future<FeedbackCommentModel> addComment(
      String feedbackId, Map<String, dynamic> data);

  // Release notes (public)
  Future<List<ReleaseNoteModel>> getReleaseNotes();
  Future<ReleaseNoteModel> getReleaseNoteDetail(String id);
  Future<ReleaseNoteModel> getLatestReleaseNote();

  // Admin endpoints
  Future<List<FeedbackPostModel>> getAdminFeedbacks({
    String? status,
    String? category,
  });
  Future<FeedbackPostModel> updateFeedbackStatus(
      String feedbackId, Map<String, dynamic> data);
  Future<FeedbackCommentModel> addAdminComment(
      String feedbackId, Map<String, dynamic> data);
  Future<void> updateAdminNote(String feedbackId, Map<String, dynamic> data);
  Future<FeedbackStatsModel> getFeedbackStats();

  // Public board + voting
  Future<(List<PublicFeedbackModel>, int totalElements, int totalPages)>
      getPublicFeedbacks({
    String sort = 'latest',
    String? category,
    String? status,
    int page = 0,
    int size = 20,
  });
  Future<List<PublicFeedbackModel>> getTopFeedbacks();
  Future<VoteResponseModel> toggleVote(String feedbackId);

  // Admin release note management
  Future<ReleaseNoteModel> createReleaseNote(Map<String, dynamic> data);
  Future<ReleaseNoteModel> updateReleaseNote(
      String id, Map<String, dynamic> data);
  Future<void> deleteReleaseNote(String id);
  Future<ReleaseNoteModel> publishReleaseNote(String id);
  Future<ReleaseNoteModel> linkFeedbackToRelease(
      String releaseId, Map<String, dynamic> data);
}

class FeedbackRemoteDataSourceImpl implements FeedbackRemoteDataSource {
  final ApiClient apiClient;

  FeedbackRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<FeedbackPostModel>> getFeedbacks() async {
    final response = await apiClient.dio.get(ApiEndpoints.feedback);
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => FeedbackPostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<FeedbackPostModel> createFeedback(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.feedback,
      data: data,
    );
    return FeedbackPostModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<FeedbackPostModel> getFeedbackDetail(String id) async {
    final response = await apiClient.dio.get('${ApiEndpoints.feedback}/$id');
    return FeedbackPostModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<FeedbackCommentModel> addComment(
      String feedbackId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      '${ApiEndpoints.feedback}/$feedbackId/comments',
      data: data,
    );
    return FeedbackCommentModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<ReleaseNoteModel>> getReleaseNotes() async {
    final response = await apiClient.dio.get(ApiEndpoints.releases);
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => ReleaseNoteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ReleaseNoteModel> getReleaseNoteDetail(String id) async {
    final response = await apiClient.dio.get('${ApiEndpoints.releases}/$id');
    return ReleaseNoteModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<ReleaseNoteModel> getLatestReleaseNote() async {
    final response =
        await apiClient.dio.get('${ApiEndpoints.releases}/latest');
    return ReleaseNoteModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<FeedbackPostModel>> getAdminFeedbacks({
    String? status,
    String? category,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status;
    if (category != null) queryParams['category'] = category;

    final response = await apiClient.dio.get(
      ApiEndpoints.adminFeedback,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => FeedbackPostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<FeedbackPostModel> updateFeedbackStatus(
      String feedbackId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.patch(
      '${ApiEndpoints.adminFeedback}/$feedbackId/status',
      data: data,
    );
    return FeedbackPostModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<FeedbackCommentModel> addAdminComment(
      String feedbackId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      '${ApiEndpoints.adminFeedback}/$feedbackId/comments',
      data: data,
    );
    return FeedbackCommentModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> updateAdminNote(
      String feedbackId, Map<String, dynamic> data) async {
    await apiClient.dio.patch(
      '${ApiEndpoints.adminFeedback}/$feedbackId/note',
      data: data,
    );
  }

  @override
  Future<FeedbackStatsModel> getFeedbackStats() async {
    final response =
        await apiClient.dio.get('${ApiEndpoints.adminFeedback}/stats');
    return FeedbackStatsModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<ReleaseNoteModel> createReleaseNote(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.adminReleases,
      data: data,
    );
    return ReleaseNoteModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<ReleaseNoteModel> updateReleaseNote(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put(
      '${ApiEndpoints.adminReleases}/$id',
      data: data,
    );
    return ReleaseNoteModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteReleaseNote(String id) async {
    await apiClient.dio.delete('${ApiEndpoints.adminReleases}/$id');
  }

  @override
  Future<ReleaseNoteModel> publishReleaseNote(String id) async {
    final response = await apiClient.dio.patch(
      '${ApiEndpoints.adminReleases}/$id/publish',
    );
    return ReleaseNoteModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<ReleaseNoteModel> linkFeedbackToRelease(
      String releaseId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      '${ApiEndpoints.adminReleases}/$releaseId/link-feedback',
      data: data,
    );
    return ReleaseNoteModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<(List<PublicFeedbackModel>, int totalElements, int totalPages)>
      getPublicFeedbacks({
    String sort = 'latest',
    String? category,
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'sort': sort,
      'page': page,
      'size': size,
    };
    if (category != null) queryParams['category'] = category;
    if (status != null) queryParams['status'] = status;

    final response = await apiClient.dio.get(
      ApiEndpoints.feedbackPublic,
      queryParameters: queryParams,
    );
    final pageData = response.data['data'] as Map<String, dynamic>;
    final content = pageData['content'] as List<dynamic>;
    final items = content
        .map((e) => PublicFeedbackModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      items,
      pageData['totalElements'] as int? ?? 0,
      pageData['totalPages'] as int? ?? 0,
    );
  }

  @override
  Future<List<PublicFeedbackModel>> getTopFeedbacks() async {
    final response = await apiClient.dio.get(ApiEndpoints.feedbackPublicTop);
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => PublicFeedbackModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<VoteResponseModel> toggleVote(String feedbackId) async {
    final response = await apiClient.dio.post(
      '${ApiEndpoints.feedback}/$feedbackId/vote',
    );
    return VoteResponseModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
