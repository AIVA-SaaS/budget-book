import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/pocket/data/datasources/pocket_remote_datasource.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/domain/entities/distribute_result.dart';
import 'package:budget_book/features/pocket/domain/repositories/pocket_repository.dart';

class PocketRepositoryImpl implements PocketRepository {
  final PocketRemoteDataSource remoteDataSource;

  PocketRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<MoneyPocket>>> getPockets() async {
    try {
      final result = await remoteDataSource.getPockets();
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to load pockets'));
    }
  }

  @override
  Future<Either<Failure, MoneyPocket>> createPocket({
    required String name,
    required String type,
    required int allocatedAmount,
    String? icon,
    String? color,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'type': type,
        'allocatedAmount': allocatedAmount,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
      };
      final result = await remoteDataSource.createPocket(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to create pocket'));
    }
  }

  @override
  Future<Either<Failure, MoneyPocket>> updatePocket({
    required String id,
    String? name,
    String? type,
    int? allocatedAmount,
    String? icon,
    String? color,
    int? displayOrder,
  }) async {
    try {
      final data = <String, dynamic>{
        if (name != null) 'name': name,
        if (type != null) 'type': type,
        if (allocatedAmount != null) 'allocatedAmount': allocatedAmount,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (displayOrder != null) 'displayOrder': displayOrder,
      };
      final result = await remoteDataSource.updatePocket(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to update pocket'));
    }
  }

  @override
  Future<Either<Failure, void>> deletePocket(String id) async {
    try {
      await remoteDataSource.deletePocket(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to delete pocket'));
    }
  }

  @override
  Future<Either<Failure, DistributeResult>> distributeIncome({
    required int totalAmount,
    required List<Map<String, dynamic>> distributions,
  }) async {
    try {
      final data = <String, dynamic>{
        'totalAmount': totalAmount,
        'distributions': distributions,
      };
      final result = await remoteDataSource.distributeIncome(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to distribute income'));
    }
  }

  Failure _mapDioError(DioException e, String defaultMessage) {
    final errorData = e.response?.data?['error'];
    return ServerFailure(
      errorData?['message'] as String? ?? defaultMessage,
      errorData?['code'] as String?,
      e.response?.statusCode,
    );
  }
}
