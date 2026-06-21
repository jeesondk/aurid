//! Aurid Migration Tool
//! 
//! A command-line tool for migrating users, groups, and policies from
//! Active Directory to FreeIPA as part of the Aurid platform.
//!
//! This tool is designed to be:
//! - Safe: Dry-run mode, validation, and rollback support
//! - Fast: Parallel processing and batch operations
//! - Reliable: Comprehensive error handling and retry logic
//! - Auditable: Detailed logging and reporting

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use std::path::PathBuf;
use tracing::{debug, error, info, warn};

mod ad;
mod config;
mod freeipa;
mod migration;
mod models;
mod reporting;

/// Aurid Migration Tool - Active Directory to FreeIPA Migration
#[derive(Parser, Debug)]
#[command(name = "aurid-migrate")]
#[command(author = "Aurid ApS <team@aurid.io>")]
#[command(version = "0.1.0")]
#[command(about = "Migrate Active Directory to FreeIPA for Aurid platform")]
#[command(long_about = None)]
struct Cli {
    /// Enable verbose logging
    #[arg(short, long, env = "AURID_VERBOSE")]
    verbose: bool,

    /// Dry run mode - no changes will be made
    #[arg(short, long, env = "AURID_DRY_RUN")]
    dry_run: bool,

    /// Configuration file path
    #[arg(short, long, env = "AURID_CONFIG", default_value = "config.toml")]
    config: PathBuf,

    /// Output directory for reports
    #[arg(short, long, env = "AURID_OUTPUT_DIR", default_value = "./output")]
    output_dir: PathBuf,

    #[command(subcommand)]
    command: Commands,
}

/// Available commands
#[derive(Subcommand, Debug)]
enum Commands {
    /// Run a full migration
    Migrate {
        /// Migration plan file
        #[arg(short, long)]
        plan: Option<PathBuf>,

        /// Batch size for processing
        #[arg(short, long, default_value = "100")]
        batch_size: usize,

        /// Number of parallel workers
        #[arg(short, long, default_value = "4")]
        workers: usize,
    },

    /// Validate AD connection and data
    Validate {
        /// Test LDAP connection only
        #[arg(short, long)]
        connection_only: bool,

        /// Sample size for data validation
        #[arg(short, long, default_value = "10")]
        sample_size: usize,
    },

    /// Export data from Active Directory
    Export {
        /// Export format (json, csv)
        #[arg(short, long, default_value = "json")]
        format: String,

        /// Export only specific OUs
        #[arg(short, long)]
        ou_filter: Option<String>,

        /// Export only specific groups
        #[arg(short, long)]
        group_filter: Option<String>,
    },

    /// Import data to FreeIPA
    Import {
        /// Input file path
        #[arg(short, long)]
        input: PathBuf,

        /// Skip existing entries
        #[arg(short, long)]
        skip_existing: bool,
    },

    /// Generate a migration plan
    Plan {
        /// Output file path
        #[arg(short, long)]
        output: Option<PathBuf>,

        /// Include group memberships
        #[arg(short, long)]
        include_groups: bool,

        /// Include password hashes (if available)
        #[arg(short, long)]
        include_passwords: bool,
    },

    /// Show migration status and progress
    Status {
        /// Migration ID to check
        #[arg(short, long)]
        migration_id: Option<String>,
    },

    /// Rollback a migration
    Rollback {
        /// Migration ID to rollback
        #[arg(short, long)]
        migration_id: String,

        /// Force rollback without confirmation
        #[arg(short, long)]
        force: bool,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    init_logging()?;

    let cli = Cli::parse();

    // Set up configuration
    let config = config::Config::load(&cli.config)
        .with_context(|| format!("Failed to load configuration from {:?}", cli.config))?;

    debug!("Configuration loaded: {:?}", config);

    // Create output directory if it doesn't exist
    if !cli.output_dir.exists() {
        std::fs::create_dir_all(&cli.output_dir)
            .with_context(|| format!("Failed to create output directory: {:?}", cli.output_dir))?;
    }

    // Execute the command
    match cli.command {
        Commands::Migrate {
            plan,
            batch_size,
            workers,
        } => {
            migration::run_migration(&config, cli.dry_run, batch_size, workers, plan, &cli.output_dir)
                .await?;
        }
        Commands::Validate {
            connection_only,
            sample_size,
        } => {
            ad::validate(&config, connection_only, sample_size).await?;
        }
        Commands::Export {
            format,
            ou_filter,
            group_filter,
        } => {
            let output_path = cli.output_dir.join("ad_export.#{format}");
            ad::export_data(&config, &output_path, &format, ou_filter, group_filter).await?;
        }
        Commands::Import {
            input,
            skip_existing,
        } => {
            freeipa::import_data(&config, &input, skip_existing).await?;
        }
        Commands::Plan {
            output,
            include_groups,
            include_passwords,
        } => {
            let output_path = output.unwrap_or_else(|| cli.output_dir.join("migration_plan.json"));
            migration::generate_plan(&config, &output_path, include_groups, include_passwords).await?;
        }
        Commands::Status { migration_id } => {
            migration::show_status(&config, migration_id, &cli.output_dir).await?;
        }
        Commands::Rollback {
            migration_id,
            force,
        } => {
            migration::rollback(&config, &migration_id, force).await?;
        }
    }

    Ok(())
}

/// Initialize logging based on CLI flags
fn init_logging() -> Result<()> {
    use tracing_subscriber::{fmt, prelude::*, EnvFilter};

    let filter = EnvFilter::try_from_default_env()
        .or_else(|_| EnvFilter::try_new("info"))?;

    fmt()
        .with_env_filter(filter)
        .with_target(true)
        .with_line_number(true)
        .with_file(true)
        .init();

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cli_parsing() {
        // Test that CLI parsing works correctly
        let cli = Cli::parse_from(["aurid-migrate", "--verbose", "validate"]);
        assert!(cli.verbose);
        assert!(matches!(cli.command, Commands::Validate { .. }));
    }
}
