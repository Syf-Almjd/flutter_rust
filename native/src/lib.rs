mod api;
mod db;

// Export all functions to be used by flutter_rust_bridge
pub use api::*;
// Re-export the generated bridge
#[allow(dead_code)]
pub mod bridge_generated {
    // Include the generated bridge code
    include!(concat!(env!("OUT_DIR"), "/bridge_generated.rs"));
}