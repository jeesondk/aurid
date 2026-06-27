//! Reporting module
//! 
//! Handles generation of migration reports

use anyhow::Result;
use chrono::Local;
use std::fs::File;
use std::io::Write;
use std::path::Path;

use crate::models::MigrationResult;

/// Report generator
pub struct ReportGenerator {
    output_dir: std::path::PathBuf,
}

impl ReportGenerator {
    /// Create a new report generator
    pub fn new(output_dir: &Path) -> Self {
        Self {
            output_dir: output_dir.to_path_buf(),
        }
    }

    /// Generate a JSON report
    pub fn generate_json_report(&self, result: &MigrationResult) -> Result<()> {
        let report_path = self.output_dir.join("migration_report.json");
        let json = serde_json::to_string_pretty(result)?;
        std::fs::write(report_path, json)?;
        Ok(())
    }

    /// Generate a summary report
    pub fn generate_summary_report(&self, result: &MigrationResult) -> Result<()> {
        let report_path = self.output_dir.join("migration_summary.txt");
        let mut file = File::create(report_path)?;
        
        writeln!(file, "=== Migration Summary ===")?;
        writeln!(file, "Generated: {}", Local::now().format("%Y-%m-%d %H:%M:%S"))?;
        writeln!(file)?;
        writeln!(file, "Users:")?;
        writeln!(file, "  Created: {}", result.users_created)?;
        writeln!(file, "  Updated: {}", result.users_updated)?;
        writeln!(file, "  Failed: {}", result.users_failed)?;
        writeln!(file)?;
        writeln!(file, "Groups:")?;
        writeln!(file, "  Created: {}", result.groups_created)?;
        writeln!(file, "  Updated: {}", result.groups_updated)?;
        writeln!(file, "  Failed: {}", result.groups_failed)?;
        writeln!(file)?;
        
        if !result.errors.is_empty() {
            writeln!(file, "Errors:")?;
            for (key, value) in &result.errors {
                writeln!(file, "  {}: {}", key, value)?;
            }
        }
        
        Ok(())
    }
}
