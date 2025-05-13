
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../database/db_service.dart';
import 'query_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DBService _dbService = DBService();
  final TextEditingController _tableNameController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = '';
  List<TableInfo> _tables = [];

  @override
  void initState() {
    super.initState();
    _initializeDB();
  }

  Future<void> _initializeDB() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing DuckDB...';
    });

    try {
      await _dbService.initialize();
      await _loadTables();
      setState(() {
        _statusMessage = 'DuckDB initialized successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize DuckDB: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTables() async {
    try {
      final tables = await _dbService.getTables();
      setState(() {
        _tables = tables;
      });
    } catch (e) {
      print('Error loading tables: $e');
    }
  }

  Future<void> _importParquetFile() async {
    if (_tableNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a table name')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Selecting Parquet file...';
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['parquet'],
      );

      if (result != null) {
        setState(() {
          _statusMessage = 'Importing Parquet file...';
        });

        final filePath = result.files.single.path!;
        final tableName = _tableNameController.text.trim();
        
        final success = await _dbService.importParquetFile(filePath, tableName);
        
        if (success) {
          setState(() {
            _statusMessage = 'Parquet file imported successfully';
          });
          await _loadTables();
        } else {
          setState(() {
            _statusMessage = 'Failed to import Parquet file';
          });
        }
      } else {
        setState(() {
          _statusMessage = 'No file selected';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error importing file: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToQueryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QueryPage(tables: _tables),
      ),
    ).then((_) => _loadTables());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DuckDB Flutter'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _tableNameController,
              decoration: const InputDecoration(
                labelText: 'Table Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _importParquetFile,
              child: const Text('Import Parquet File'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _navigateToQueryPage,
              child: const Text('Run SQL Queries'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tables:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(_statusMessage),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _tables.length,
                      itemBuilder: (context, index) {
                        final table = _tables[index];
                        return Card(
                          child: ListTile(
                            title: Text(table.name),
                            subtitle: Text(
                                'Rows: ${table.rowCount} | Size: ${(table.sizeBytes / 1024).toStringAsFixed(2)} KB'),
                            trailing: const Icon(Icons.table_chart),
                            onTap: () {
                              // Show table details
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(table.name),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                            'Row count: ${table.rowCount}'),
                                        Text(
                                            'Size: ${(table.sizeBytes / 1024).toStringAsFixed(2)} KB'),
                                        const SizedBox(height: 8),
                                        const Text('Columns:',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        ...table.columns.map((col) => Padding(
                                              padding:
                                                  const EdgeInsets.only(left: 8.0),
                                              child: Text(
                                                  '${col.name} (${col.dataType}${col.nullable ? ', nullable' : ''})'),
                                            )),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tableNameController.dispose();
    super.dispose();
  }
}