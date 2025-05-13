use std::io::Result;
use flutter_rust_bridge_codegen::codegen_options::CodegenOptions;

fn main() -> Result<()> {
    let options = CodegenOptions::default();
    let out_dir = std::env::var("OUT_DIR").unwrap();
    let out_file = std::path::Path::new(&out_dir).join("bridge_generated.rs");
    
    flutter_rust_bridge_codegen::codegen(
        &options,
        &["src/api.rs", "src/db.rs"],
        &out_file,
    ).unwrap();
    
    println!("cargo:rerun-if-changed=src/api.rs");
    println!("cargo:rerun-if-changed=src/db.rs");
    Ok(())
}