//! Configuration management for the migration tool

use anyhow::{Context, Result};
use config::{Config as ConfigLib, File, Environment};
use serde::{Deserialize, Serialize};
use std::path::Path;

/// Main configuration structure
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Config {
    /// Active Directory configuration
    pub active_directory: ADConfig,
    
    /// FreeIPA configuration
    pub freeipa: FreeIPAConfig,
    
    /// Migration settings
    pub migration: MigrationConfig,
    
    /// Logging configuration
    #[serde(default)]
    pub logging: LoggingConfig,
    
    /// Performance settings
    #[serde(default)]
    pub performance: PerformanceConfig,
}

/// Active Directory configuration
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ADConfig {
    /// AD server host or IP
    pub host: String,
    
    /// AD server port
    #[serde(default = "default_ad_port")]
    pub port: u16,
    
    /// Use SSL/TLS
    #[serde(default = "default_ad_ssl")]
    pub use_ssl: bool,
    
    /// Bind DN for authentication
    pub bind_dn: String,
    
    /// Bind password
    pub bind_password: String,
    
    /// Base DN for searches
    pub base_dn: String,
    
    /// Domain name
    pub domain: String,
    
    /// Forest name (if different from domain)
    #[serde(default)]
    pub forest: Option<String>,
    
    /// Timeout in seconds
    #[serde(default = "default_ad_timeout")]
    pub timeout: u64,
    
    /// Page size for paged results
    #[serde(default = "default_ad_page_size")]
    pub page_size: u32,
    
    /// Filter for user search
    #[serde(default = "default_ad_user_filter")]
    pub user_filter: String,
    
    /// Filter for group search
    #[serde(default = "default_ad_group_filter")]
    pub group_filter: String,
    
    /// Attributes to fetch for users
    #[serde(default = "default_ad_user_attributes")]
    pub user_attributes: Vec<String>,
    
    /// Attributes to fetch for groups
    #[serde(default = "default_ad_group_attributes")]
    pub group_attributes: Vec<String>,
}

fn default_ad_port() -> u16 { 389 }
fn default_ad_ssl() -> bool { false }
fn default_ad_timeout() -> u64 { 30 }
fn default_ad_page_size() -> u32 { 1000 }
fn default_ad_user_filter() -> String { "(objectClass=user)".to_string() }
fn default_ad_group_filter() -> String { "(objectClass=group)".to_string() }
fn default_ad_user_attributes() -> Vec<String> {
    vec![
        "objectClass".to_string(),
        "cn".to_string(),
        "givenName".to_string(),
        "sn".to_string(),
        "displayName".to_string(),
        "mail".to_string(),
        "userPrincipalName".to_string(),
        "sAMAccountName".to_string(),
        "distinguishedName".to_string(),
        "memberOf".to_string(),
        "primaryGroupID".to_string(),
        "userPassword".to_string(),
        "unicodePwd".to_string(),
        "pwdLastSet".to_string(),
        "userAccountControl".to_string(),
        "accountExpires".to_string(),
        "whenCreated".to_string(),
        "whenChanged".to_string(),
    ]
}
fn default_ad_group_attributes() -> Vec<String> {
    vec![
        "objectClass".to_string(),
        "cn".to_string(),
        "description".to_string(),
        "member".to_string(),
        "distinguishedName".to_string(),
        "groupType".to_string(),
        "whenCreated".to_string(),
        "whenChanged".to_string(),
    ]
}

/// FreeIPA configuration
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct FreeIPAConfig {
    /// FreeIPA server host or IP
    pub host: String,
    
    /// FreeIPA server port
    #[serde(default = "default_ipa_port")]
    pub port: u16,
    
    /// Use HTTPS
    #[serde(default = "default_ipa_https")]
    pub use_https: bool,
    
    /// Admin username
    pub username: String,
    
    /// Admin password
    pub password: String,
    
    /// Base DN
    pub base_dn: String,
    
    /// Realm name
    pub realm: String,
    
    /// Domain name
    pub domain: String,
    
    /// Timeout in seconds
    #[serde(default = "default_ipa_timeout")]
    pub timeout: u64,
    
    /// API version
    #[serde(default = "default_ipa_api_version")]
    pub api_version: String,
    
    /// Verify SSL certificates
    #[serde(default = "default_ipa_verify_ssl")]
    pub verify_ssl: bool,
}

fn default_ipa_port() -> u16 { 443 }
fn default_ipa_https() -> bool { true }
fn default_ipa_timeout() -> u64 { 30 }
fn default_ipa_api_version() -> String { "2.230".to_string() }
fn default_ipa_verify_ssl() -> bool { true }

/// Migration configuration
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct MigrationConfig {
    /// Migration ID (generated if not provided)
    #[serde(default)]
    pub migration_id: Option<String>,
    
    /// Batch size for processing
    #[serde(default = "default_migration_batch_size")]
    pub batch_size: usize,
    
    /// Number of parallel workers
    #[serde(default = "default_migration_workers")]
    pub workers: usize,
    
    /// Enable dry run mode
    #[serde(default)]
    pub dry_run: bool,
    
    /// Skip existing entries
    #[serde(default)]
    pub skip_existing: bool,
    
    /// Include group memberships
    #[serde(default = "default_migration_include_groups")]
    pub include_groups: bool,
    
    /// Include password hashes
    #[serde(default)]
    pub include_passwords: bool,
    
    /// Password hash algorithm for export
    #[serde(default = "default_migration_password_algorithm")]
    pub password_algorithm: String,
    
    /// Conflict resolution strategy
    #[serde(default = "default_migration_conflict_strategy")]
    pub conflict_strategy: ConflictStrategy,
    
    /// Rollback on failure
    #[serde(default = "default_migration_rollback_on_failure")]
    pub rollback_on_failure: bool,
}

fn default_migration_batch_size() -> usize { 100 }
fn default_migration_workers() -> usize { 4 }
fn default_migration_include_groups() -> bool { true }
fn default_migration_password_algorithm() -> String { "SSHA512".to_string() }
fn default_migration_conflict_strategy() -> ConflictStrategy { ConflictStrategy::Skip }
fn default_migration_rollback_on_failure() -> bool { true }

/// Conflict resolution strategy
#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum ConflictStrategy {
    /// Skip existing entries
    Skip,
    /// Overwrite existing entries
    Overwrite,
    /// Rename new entries
    Rename,
    /// Fail on conflict
    Fail,
}

/// Logging configuration
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct LoggingConfig {
    /// Log level
    #[serde(default = "default_logging_level")]
    pub level: String,
    
    /// Log format (text, json)
    #[serde(default = "default_logging_format")]
    pub format: String,
    
    /// Log file path
    #[serde(default)]
    pub file: Option<String>,
    
    /// Enable console logging
    #[serde(default = "default_logging_console")]
    pub console: bool,
}

fn default_logging_level() -> String { "info".to_string() }
fn default_logging_format() -> String { "text".to_string() }
fn default_logging_console() -> bool { true }

/// Performance configuration
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct PerformanceConfig {
    /// Maximum memory usage in MB
    #[serde(default = "default_performance_max_memory")]
    pub max_memory: usize,
    
    /// Maximum CPU usage percentage
    #[serde(default = "default_performance_max_cpu")]
    pub max_cpu: usize,
    
    /// Retry count for failed operations
    #[serde(default = "default_performance_retry_count")]
    pub retry_count: usize,
    
    /// Retry delay in milliseconds
    #[serde(default = "default_performance_retry_delay")]
    pub retry_delay: u64,
}

fn default_performance_max_memory() -> usize { 2048 }
fn default_performance_max_cpu() -> usize { 80 }
fn default_performance_retry_count() -> usize { 3 }
fn default_performance_retry_delay() -> u64 { 1000 }

impl Config {
    /// Load configuration from file
    pub fn load(path: &Path) -> Result<Self> {
        let mut builder = ConfigLib::builder()
            .add_source(File::from(path));
        
        // Add environment variables with AURID_ prefix
        builder = builder.add_source(Environment::with_prefix("aurid"));
        
        // Add default values
        builder = builder.set_default("active_directory.port", 389)?;
        builder = builder.set_default("active_directory.use_ssl", false)?;
        builder = builder.set_default("active_directory.timeout", 30)?;
        
        let settings = builder.build()?;
        
        settings.try_deserialize()
            .context("Failed to deserialize configuration")
    }
    
    /// Save configuration to file
    pub fn save(&self, path: &Path) -> Result<()> {
        let toml_string = toml::to_string(self)
            .context("Failed to serialize configuration to TOML")?;
        
        std::fs::write(path, toml_string)
            .context("Failed to write configuration file")?;
        
        Ok(())
    }
    
    /// Generate a new migration ID
    pub fn generate_migration_id(&mut self) {
        use uuid::Uuid;
        self.migration.migration_id = Some(Uuid::new_v4().to_string());
    }
}

impl Default for Config {
    fn default() -> Self {
        Config {
            active_directory: ADConfig {
                host: "localhost".to_string(),
                port: 389,
                use_ssl: false,
                bind_dn: "".to_string(),
                bind_password: "".to_string(),
                base_dn: "".to_string(),
                domain: "".to_string(),
                forest: None,
                timeout: 30,
                page_size: 1000,
                user_filter: "(objectClass=user)".to_string(),
                group_filter: "(objectClass=group)".to_string(),
                user_attributes: default_ad_user_attributes(),
                group_attributes: default_ad_group_attributes(),
            },
            freeipa: FreeIPAConfig {
                host: "localhost".to_string(),
                port: 443,
                use_https: true,
                username: "admin".to_string(),
                password: "".to_string(),
                base_dn: "dc=aurid,dc=io".to_string(),
                realm: "AURID.IO".to_string(),
                domain: "aurid.io".to_string(),
                timeout: 30,
                api_version: "2.230".to_string(),
                verify_ssl: true,
            },
            migration: MigrationConfig {
                migration_id: None,
                batch_size: 100,
                workers: 4,
                dry_run: false,
                skip_existing: true,
                include_groups: true,
                include_passwords: false,
                password_algorithm: "SSHA512".to_string(),
                conflict_strategy: ConflictStrategy::Skip,
                rollback_on_failure: true,
            },
            logging: LoggingConfig {
                level: "info".to_string(),
                format: "text".to_string(),
                file: None,
                console: true,
            },
            performance: PerformanceConfig {
                max_memory: 2048,
                max_cpu: 80,
                retry_count: 3,
                retry_delay: 1000,
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;

    #[test]
    fn test_default_config() {
        let config = Config::default();
        assert_eq!(config.active_directory.port, 389);
        assert_eq!(config.freeipa.port, 443);
        assert_eq!(config.migration.batch_size, 100);
    }

    #[test]
    fn test_load_and_save_config() {
        let mut config = Config::default();
        config.active_directory.host = "ad.example.com".to_string();
        config.freeipa.host = "ipa.example.com".to_string();
        
        let temp_file = NamedTempFile::new().unwrap();
        let path = temp_file.path();
        
        config.save(path).unwrap();
        let loaded_config = Config::load(path).unwrap();
        
        assert_eq!(loaded_config.active_directory.host, "ad.example.com");
        assert_eq!(loaded_config.freeipa.host, "ipa.example.com");
    }

    #[test]
    fn test_generate_migration_id() {
        let mut config = Config::default();
        assert!(config.migration.migration_id.is_none());
        
        config.generate_migration_id();
        assert!(config.migration.migration_id.is_some());
        assert!(!config.migration.migration_id.unwrap().is_empty());
    }
}
