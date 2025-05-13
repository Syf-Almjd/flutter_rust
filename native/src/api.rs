use crate::db::{
    initialize_db, import_parquet, execute_query, get_tables_info, 
    get_indices_info, create_index, QueryResult, TableInfo, IndexInfo
};

pub fn init_database(db_path: String) -> anyhow::Result<bool> {
    initialize_db(db_path)
}

pub fn import_parquet_file(file_path: String, table_name: String) -> anyhow::Result<bool> {
    import_parquet(file_path, table_name)
}

pub fn run_query(query: String) -> anyhow::Result<QueryResult> {
    execute_query(query)
}

pub fn get_all_tables() -> anyhow::Result<Vec<TableInfo>> {
    get_tables_info()
}

pub fn get_all_indices() -> anyhow::Result<Vec<IndexInfo>> {
    get_indices_info()
}

pub fn create_table_index(table_name: String, column_name: String) -> anyhow::Result<bool> {
    create_index(table_name, column_name)
}