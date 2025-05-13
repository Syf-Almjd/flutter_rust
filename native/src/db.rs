use anyhow::{anyhow, Result};
use duckdb::{Connection, params};
use once_cell::sync::Lazy;
use std::sync::Mutex;
use std::collections::HashMap;
use std::time::{Instant, Duration};
use chrono::prelude::*;

// Structure to hold database information
pub struct DatabaseInfo {
    pub table_count: i32,
    pub row_count: HashMap<String, i64>,
    pub table_schemas: HashMap<String, String>,
    pub indices: HashMap<String, Vec<String>>,
}

// Structure to hold query results
pub struct QueryResult {
    pub column_names: Vec<String>,
    pub rows: Vec<Vec<String>>,
    pub execution_time_ms: f64,
    pub row_count: i64,
}

// Static connection instance
static DB_CONNECTION: Lazy<Mutex<Option<Connection>>> = Lazy::new(|| Mutex::new(None));

// Initialize DuckDB connection
pub fn init_database() -> Result<String> {
    let mut conn_guard = DB_CONNECTION.lock().map_err(|_| anyhow!("Failed to lock database connection"))?;
    
    // Create a new in-memory database
    let conn = Connection::open_in_memory()?;
    *conn_guard = Some(conn);
    
    Ok("DuckDB initialized successfully".to_string())
}

// Import Parquet file
pub fn import_parquet(file_path: String) -> Result<String> {
    let mut conn_guard = DB_CONNECTION.lock().map_err(|_| anyhow!("Failed to lock database connection"))?;
    
    let conn = conn_guard.as_ref().ok_or_else(|| anyhow!("Database not initialized"))?;
    
    // Extract table name from file path
    let file_name = std::path::Path::new(&file_path)
        .file_stem()
        .and_then(|s| s.to_str())
        .ok_or_else(|| anyhow!("Invalid file path"))?;
    
    // Safe table name (remove special characters)
    let table_name = file_name.replace(|c: char| !c.is_alphanumeric() && c != '_', "_");
    
    // Create table from Parquet file
    conn.execute_batch(&format!(
        "CREATE TABLE {} AS SELECT * FROM read_parquet('{}');",
        table_name, file_path
    ))?;
    
    // Get row count
    let mut stmt = conn.prepare(&format!("SELECT COUNT(*) FROM {}", table_name))?;
    let row_count: i64 = stmt.query_row(params![], |row| row.get(0))?;
    
    Ok(format!("Imported {} rows into table {}", row_count, table_name))
}

// Execute SQL query
pub fn execute_query(query: String) -> Result<QueryResult> {
    let conn_guard = DB_CONNECTION.lock().map_err(|_| anyhow!("Failed to lock database connection"))?;
    let conn = conn_guard.as_ref().ok_or_else(|| anyhow!("Database not initialized"))?;
    
    // Measure execution time
    let start = Instant::now();
    let mut stmt = conn.prepare(&query)?;
    
    // Get column names
    let column_names: Vec<String> = stmt
        .column_names()
        .into_iter()
        .map(|s| s.to_string())
        .collect();
    
    // Execute query and collect results
    let rows_result = stmt.query_map(params![], |row| {
        let mut row_data = Vec::new();
        for i in 0..row.column_count() {
            let value: String = match row.get_ref(i) {
                Ok(val) => {
                    match val {
                        duckdb::types::ValueRef::Null => "NULL".to_string(),
                        duckdb::types::ValueRef::Integer(i) => i.to_string(),
                        duckdb::types::ValueRef::Real(f) => f.to_string(),
                        duckdb::types::ValueRef::Text(t) => String::from_utf8_lossy(t).to_string(),
                        duckdb::types::ValueRef::Blob(b) => format!("BLOB({})", b.len()),
                    }
                },
                Err(_) => "ERROR".to_string(),
            };
            row_data.push(value);
        }
        Ok(row_data)
    })?;
    
    let mut rows = Vec::new();
    let mut row_count = 0;
    for row in rows_result {
        rows.push(row?);
        row_count += 1;
    }
    
    let duration = start.elapsed();
    
    Ok(QueryResult {
        column_names,
        rows,
        execution_time_ms: duration.as_secs_f64() * 1000.0,
        row_count,
    })
}

// Get database information
pub fn get_database_info() -> Result<DatabaseInfo> {
    let conn_guard = DB_CONNECTION.lock().map_err(|_| anyhow!("Failed to lock database connection"))?;
    let conn = conn_guard.as_ref().ok_or_else(|| anyhow!("Database not initialized"))?;
    
    // Get list of tables
    let mut tables_stmt = conn.prepare("SELECT name FROM sqlite_master WHERE type='table'")?;
    let tables_rows = tables_stmt.query_map(params![], |row| row.get::<_, String>(0))?;
    
    let mut table_count = 0;
    let mut row_count = HashMap::new();
    let mut table_schemas = HashMap::new();
    let mut indices = HashMap::new();
    
    for table_result in tables_rows {
        let table_name = table_result?;
        table_count += 1;
        
        // Get row count for each table
        let mut count_stmt = conn.prepare(&format!("SELECT COUNT(*) FROM {}", table_name))?;
        let count: i64 = count_stmt.query_row(params![], |row| row.get(0))?;
        row_count.insert(table_name.clone(), count);
        
        // Get schema for each table
        let mut schema_stmt = conn.prepare(&format!("PRAGMA table_info({})", table_name))?;
        let schema_rows = schema_stmt.query_map(params![], |row| {
            let name: String = row.get(1)?;
            let type_str: String = row.get(2)?;
            Ok(format!("{} {}", name, type_str))
        })?;
        
        let mut schema_vec = Vec::new();
        for schema_row in schema_rows {
            schema_vec.push(schema_row?);
        }
        let schema = schema_vec.join(", ");
        table_schemas.insert(table_name.clone(), schema);
        
        // Get indices for each table
        let mut index_stmt = conn.prepare(&format!("PRAGMA index_list({})", table_name))?;
        let index_rows = index_stmt.query_map(params![], |row| row.get::<_, String>(1))?;
        
        let mut index_vec = Vec::new();
        for index_row in index_rows {
            index_vec.push(index_row?);
        }
        indices.insert(table_name.clone(), index_vec);
    }
    
    Ok(DatabaseInfo {
        table_count,
        row_count,
        table_schemas,
        indices,
    })
}

// Create index on a table
pub fn create_index(table_name: String, column_name: String) -> Result<String> {
    let conn_guard = DB_CONNECTION.lock().map_err(|_| anyhow!("Failed to lock database connection"))?;
    let conn = conn_guard.as_ref().ok_or_else(|| anyhow!("Database not initialized"))?;
    
    let index_name = format!("idx_{}_{}", table_name, column_name);
    conn.execute_batch(&format!(
        "CREATE INDEX {} ON {} ({});",
        index_name, table_name, column_name
    ))?;
    
    Ok(format!("Created index {} on {}.{}", index_name, table_name, column_name))
}