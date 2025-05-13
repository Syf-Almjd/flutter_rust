
import 'dart:io';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../ffi.dart';

class DBService {
  static final DBService _instance = DBService._internal();
  bool _isInitialized = false;

  factory DBService() {
    return _instance;
  }

  DBService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(appDir.path, 'duckdb_flutter.db');
    
    try {
      await api.initDatabase(dbPath: dbPath);
      _isInitialized = true;
      print('DuckDB initialized at: $dbPath');
    } catch (e) {
      print('Failed to initialize DuckDB: $e');
      rethrow;
    }
  }

  Future<bool> importParquetFile(String filePath, String tableName) async {
    try {
      return await api.importParquetFile(
        filePath: filePath,
        tableName: tableName,
      );
    } catch (e) {
      print('Failed to import Parquet file: $e');
      rethrow;
    }
  }

  Future<QueryResult> executeQuery(String query) async {
    try {
      return await api.runQuery(query: query);
    } catch (e) {
      print('Query execution failed: $e');
      rethrow;
    }
  }

  Future<List<TableInfo>> getTables() async {
    try {
      return await api.getAllTables();
    } catch (e) {
      print('Failed to get tables: $e');
      rethrow;
    }
  }

  Future<List<IndexInfo>> getIndices() async {
    try {
      return await api.getAllIndices();
    } catch (e) {
      print('Failed to get indices: $e');
      rethrow;
    }
  }

  Future<bool> createIndex(String tableName, String columnName) async {
    try {
      return await api.createTableIndex(
        tableName: tableName,
        columnName: columnName,
      );
    } catch (e) {
      print('Failed to create index: $e');
      rethrow;
    }
  }
}