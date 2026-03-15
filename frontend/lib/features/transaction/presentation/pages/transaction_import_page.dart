import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/network/api_client.dart';

class TransactionImportPage extends StatefulWidget {
  const TransactionImportPage({super.key});

  @override
  State<TransactionImportPage> createState() => _TransactionImportPageState();
}

class _TransactionImportPageState extends State<TransactionImportPage> {
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  _ImportResult? _result;
  String? _errorMessage;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _result = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null || _selectedFile!.bytes == null) return;

    setState(() {
      _isUploading = true;
      _result = null;
      _errorMessage = null;
    });

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          _selectedFile!.bytes!,
          filename: _selectedFile!.name,
        ),
      });

      final response = await getIt<ApiClient>().dio.post(
        ApiEndpoints.transactionsImportCsv,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final data = response.data['data'] as Map<String, dynamic>?;
      if (data != null) {
        setState(() {
          _result = _ImportResult(
            successCount: data['successCount'] as int? ?? 0,
            failCount: data['failCount'] as int? ?? 0,
            errors: (data['errors'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
          );
        });
      } else {
        setState(() {
          _result = const _ImportResult(
            successCount: 0,
            failCount: 0,
            errors: [],
          );
        });
      }
    } on DioException catch (e) {
      final errorData = e.response?.data;
      String message = '가져오기에 실패했습니다';
      if (errorData is Map<String, dynamic>) {
        final error = errorData['error'] as Map<String, dynamic>?;
        if (error != null) {
          message = error['message'] as String? ?? message;
        }
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '가져오기 실패: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 가져오기'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'CSV 파일 가져오기',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'CSV 파일을 선택하여 거래 내역을 일괄 등록할 수 있습니다.\n'
                      '내보내기에서 다운로드한 CSV 형식과 동일한 형식을 사용해 주세요.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // File picker area
            InkWell(
              onTap: _isUploading ? null : _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surfaceContainerLow,
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null
                          ? Icons.description
                          : Icons.upload_file,
                      size: 48,
                      color: _selectedFile != null
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedFile != null) ...[
                      Text(
                        _selectedFile!.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatFileSize(_selectedFile!.size),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ] else ...[
                      Text(
                        '파일을 선택하세요',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CSV 파일만 지원됩니다',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Upload button
            FilledButton.icon(
              onPressed: _selectedFile != null && !_isUploading
                  ? _uploadFile
                  : null,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload),
              label: Text(_isUploading ? '가져오는 중...' : '가져오기'),
            ),

            const SizedBox(height: 24),

            // Results
            if (_result != null) ...[
              Card(
                color: _result!.failCount > 0
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _result!.failCount > 0
                                ? Icons.warning_amber
                                : Icons.check_circle,
                            color: _result!.failCount > 0
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '가져오기 결과',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${NumberFormat('#,###').format(_result!.successCount)}건 가져오기 완료'
                        '${_result!.failCount > 0 ? ', ${NumberFormat('#,###').format(_result!.failCount)}건 실패' : ''}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_result!.errors.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          '오류 목록',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _result!.errors.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  _result!.errors[index],
                                  style:
                                      theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Error message
            if (_errorMessage != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImportResult {
  final int successCount;
  final int failCount;
  final List<String> errors;

  const _ImportResult({
    required this.successCount,
    required this.failCount,
    required this.errors,
  });
}
