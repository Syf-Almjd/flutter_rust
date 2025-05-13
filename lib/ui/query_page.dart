import 'package:flutter/material.dart';
import '../database/db_service.dart';

class QueryPage extends StatefulWidget {
  final List<TableInfo> tables;

  const QueryPage({Key? key, required this.tables}) : super(key: key);

  @override
  _QueryPageState createState() => _QueryPageState();
}

class _QueryPageState extends State<QueryPage> {
  final DBService _dbService = DBService();
  final TextEditingController _queryController = TextEditingController();
  QueryResult? _queryResult;
  List<IndexInfo> _indices = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadIndices();
    
    // Initialize with a sample query if tables exist
    if (widget.tables.isNotEmpty) {
      final firstTable = widget.tables.first.name;
      _queryController.text = 'SELECT * FROM "$firstTable" LIMIT 10;';
    }
  }

  Future<void> _loadIndices() async {
    try {
      final indices = await _dbService.getIndices();
      setState(() {
        _indices = indices;
      });
    } catch (e) {
      print('Error loading indices: $e');
    }
  }

  Future<void> _executeQuery() async {
    if (_queryController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a SQL query';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _queryResult = null;
    });

    try {
      final result = await _dbService.executeQuery(_queryController.text);
      setState(() {
        _queryResult = result;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Query execution failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createIndex(String tableName, String columnName) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _dbService.createIndex(tableName, columnName);
      await _loadIndices();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Index created on $tableName.$columnName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create index: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SQL Query Tool'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _queryController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'SQL Query',
                border: OutlineInputBorder(),
                hintText: 'SELECT * FROM table_name LIMIT 10;',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _executeQuery,
                  child: const Text('Execute Query'),
                ),
                const SizedBox(width: 16),
                if (_isLoading) const CircularProgressIndicator(),
              ],
            ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (_queryResult != null) ...[
              const SizedBox(height: 16),
              Text(
                'Query completed in ${_queryResult!.executionTimeMs.toStringAsFixed(2)} ms',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              Text(
                'Rows returned: ${_queryResult!.rowCount}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: _queryResult!.columns
                          .map((col) => DataColumn(label: Text(col)))
                          .toList(),
                      rows: _queryResult!.rows
                          .map(
                            (row) => DataRow(
                              cells: row
                                  .map(
                                    (cell) => DataCell(
                                      Text(
                                        cell,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ] else
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      'Database Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Available Tables: ${widget.tables.length}'),
                              const SizedBox(height: 8),
                              Text('Available Indices: ${_indices.length}'),
                              const SizedBox(height: 16),
                              const Text('Schema Browser:',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: widget.tables.length,
                                  itemBuilder: (context, index) {
                                    final table = widget.tables[index];
                                    // Find indices for this table
                                    final tableIndices = _indices
                                        .where((idx) => idx.tableName == table.name)
                                        .toList();
                                    
                                    return ExpansionTile(
                                      title: Text(table.name),
                                      subtitle: Text(
                                          '${table.rowCount} rows | ${tableIndices.length} indices'),
                                      children: [
                                        ...table.columns.map((col) => ListTile(
                                              title: Text(col.name),
                                              subtitle: Text(
                                                  '${col.dataType}${col.nullable ? ' (nullable)' : ''}'),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.add_circle_outline),
                                                tooltip: 'Create index',
                                                onPressed: () => _createIndex(
                                                    table.name, col.name),
                                              ),
                                            )),
                                        if (tableIndices.isNotEmpty) ...[
                                          const Divider(),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 16.0, vertical: 8.0),
                                            child: Text('Indices:',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold)),
                                          ),
                                          ...tableIndices.map((idx) => Padding(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 16.0),
                                                child: ListTile(
                                                  title: Text(idx.indexName),
                                                  subtitle: Text(
                                                      'Columns: ${idx.columnNames.join(", ")}'),
                                                ),
                                              )),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }
}