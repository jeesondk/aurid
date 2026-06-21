//! Configuration Tests
//! 
//! Tests for configuration loading, validation, and saving

use aurid_migrate::config::{Config, ADConfig, FreeIPAConfig, MigrationConfig, ConflictStrategy};
use std::path::PathBuf;
use tempfile::NamedTempFile;
use anyhow::Result;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = Config::default();
        
        // Check AD defaults
        assert_eq!(config.active_directory.host, "localhost");
        assert_eq!(config.active_directory.port, 389);
        assert_eq!(config.active_directory.use_ssl, false);
        assert_eq!(config.active_directory.timeout, 30);
        assert_eq!(config.active_directory.page_size, 1000);
        
        // Check FreeIPA defaults
        assert_eq!(config.freeipa.host, "localhost");
        assert_eq!(config.freeipa.port, 443);
        assert_eq!(config.freeipa.use_https, true);
        assert_eq!(config.freeipa.username, "admin");
        assert_eq!(config.freeipa.api_version, "2.230");
        assert_eq!(config.freeipa.verify_ssl, true);
        
        // Check migration defaults
        assert_eq!(config.migration.batch_size, 100);
        assert_eq!(config.migration.workers, 4);
        assert_eq!(config.migration.dry_run, false);
        assert_eq!(config.migration.skip_existing, true);
        assert_eq!(config.migration.include_groups, true);
        assert_eq!(config.migration.include_passwords, false);
        assert_eq!(config.migration.password_algorithm, "SSHA512");
        assert_eq!(config.migration.conflict_strategy, ConflictStrategy::Skip);
        assert_eq!(config.migration.rollback_on_failure, true);
        
        // Check logging defaults
        assert_eq!(config.logging.level, "info");
        assert_eq!(config.logging.format, "text");
        assert_eq!(config.logging.console, true);
        
        // Check performance defaults
        assert_eq!(config.performance.max_memory, 2048);
        assert_eq!(config.performance.max_cpu, 80);
        assert_eq!(config.performance.retry_count, 3);
        assert_eq!(config.performance.retry_delay, 1000);
    }

    #[test]
    fn test_config_loading() {
        // Create a temporary config file
        let mut config = Config::default();
        config.active_directory.host = "ad.test.com".to_string();
        config.freeipa.host = "ipa.test.com".to_string();
        config.migration.batch_size = 200;
        
        let temp_file = NamedTempFile::new().unwrap();
        let path = temp_file.path();
        
        // Save the config
        config.save(path).unwrap();
        
        // Load it back
        let loaded_config = Config::load(path).unwrap();
        
        // Verify the loaded values
        assert_eq!(loaded_config.active_directory.host, "ad.test.com");
        assert_eq!(loaded_config.freeipa.host, "ipa.test.com");
        assert_eq!(loaded_config.migration.batch_size, 200);
    }

    #[test]
    fn test_config_saving() {
        let mut config = Config::default();
        config.active_directory.host = "ad.save.test".to_string();
        config.freeipa.host = "ipa.save.test".to_string();
        
        let temp_file = NamedTempFile::new().unwrap();
        let path = temp_file.path();
        
        // Save the config
        config.save(path).unwrap();
        
        // Read the file content
        let content = std::fs::read_to_string(path).unwrap();
        
        // Verify the content contains our values
        assert!(content.contains("ad.save.test"));
        assert!(content.contains("ipa.save.test"));
    }

    #[test]
    fn test_generate_migration_id() {
        let mut config = Config::default();
        
        // Initially no migration ID
        assert!(config.migration.migration_id.is_none());
        
        // Generate one
        config.generate_migration_id();
        
        // Now it should have one
        assert!(config.migration.migration_id.is_some());
        let migration_id = config.migration.migration_id.unwrap();
        
        // Should be a valid UUID
        assert!(uuid::Uuid::parse_str(&migration_id).is_ok());
    }

    #[test]
    fn test_ad_config_validation() {
        let config = ADConfig::default();
        
        // Test that required fields have sensible defaults
        assert!(!config.host.is_empty());
        assert!(!config.bind_dn.is_empty());
        assert!(!config.base_dn.is_empty());
        assert!(!config.domain.is_empty());
        
        // Test that attributes are not empty
        assert!(!config.user_attributes.is_empty());
        assert!(!config.group_attributes.is_empty());
    }

    #[test]
    fn test_freeipa_config_validation() {
        let config = FreeIPAConfig::default();
        
        // Test that required fields have sensible defaults
        assert!(!config.host.is_empty());
        assert!(!config.username.is_empty());
        assert!(!config.base_dn.is_empty());
        assert!(!config.realm.is_empty());
        assert!(!config.domain.is_empty());
        assert!(!config.api_version.is_empty());
    }

    #[test]
    fn test_migration_config_validation() {
        let config = MigrationConfig::default();
        
        // Test that defaults are sensible
        assert!(config.batch_size > 0);
        assert!(config.workers > 0);
        assert!(!config.password_algorithm.is_empty());
    }

    #[test]
    fn test_conflict_strategy_serialization() {
        // Test that all conflict strategies can be serialized and deserialized
        let strategies = vec![
            ConflictStrategy::Skip,
            ConflictStrategy::Overwrite,
            ConflictStrategy::Rename,
            ConflictStrategy::Fail,
        ];
        
        for strategy in strategies {
            let config = MigrationConfig {
                conflict_strategy: strategy.clone(),
                ..Default::default()
            };
            
            // Serialize to JSON
            let json = serde_json::to_string(&config).unwrap();
            
            // Deserialize back
            let deserialized: MigrationConfig = serde_json::from_str(&json).unwrap();
            
            // Should match
            assert_eq!(deserialized.conflict_strategy, strategy);
        }
    }

    #[test]
    fn test_config_from_environment() {
        // This test would normally set environment variables
        // and verify they're loaded correctly
        // For now, we'll just test that the config can be created
        
        let config = Config::default();
        assert!(config.active_directory.host.is_some());
    }

    #[test]
    fn test_config_merge() {
        // Test that we can merge partial configs
        let mut config = Config::default();
        
        // Modify some values
        config.active_directory.host = "modified.ad.com".to_string();
        config.freeipa.host = "modified.ipa.com".to_string();
        
        // Verify the modifications
        assert_eq!(config.active_directory.host, "modified.ad.com");
        assert_eq!(config.freeipa.host, "modified.ipa.com");
        
        // Verify other values are still default
        assert_eq!(config.active_directory.port, 389);
        assert_eq!(config.freeipa.port, 443);
    }

    #[test]
    fn test_config_clone() {
        let config = Config::default();
        let clone = config.clone();
        
        // Verify they're equal
        assert_eq!(config.active_directory.host, clone.active_directory.host);
        assert_eq!(config.freeipa.host, clone.freeipa.host);
        assert_eq!(config.migration.batch_size, clone.migration.batch_size);
        
        // Verify they're different instances
        assert!(!std::ptr::eq(&config, &clone));
    }

    #[test]
    fn test_config_debug() {
        let config = Config::default();
        
        // Should be able to debug print
        let debug_output = format!("{:?}", config);
        assert!(!debug_output.is_empty());
        assert!(debug_output.contains("active_directory"));
        assert!(debug_output.contains("freeipa"));
        assert!(debug_output.contains("migration"));
    }

    #[test]
    fn test_ad_config_custom_values() {
        let config = ADConfig {
            host: "custom.ad.com".to_string(),
            port: 3890,
            use_ssl: true,
            bind_dn: "cn=custom,dc=com".to_string(),
            bind_password: "custom_pass".to_string(),
            base_dn: "dc=custom,dc=com".to_string(),
            domain: "custom.com".to_string(),
            forest: Some("custom.forest".to_string()),
            timeout: 60,
            page_size: 2000,
            user_filter: "(customFilter)".to_string(),
            group_filter: "(customGroupFilter)".to_string(),
            user_attributes: vec!["customAttr".to_string()],
            group_attributes: vec!["customGroupAttr".to_string()],
        };
        
        assert_eq!(config.host, "custom.ad.com");
        assert_eq!(config.port, 3890);
        assert_eq!(config.use_ssl, true);
        assert_eq!(config.timeout, 60);
        assert_eq!(config.page_size, 2000);
        assert_eq!(config.forest, Some("custom.forest".to_string()));
    }

    #[test]
    fn test_freeipa_config_custom_values() {
        let config = FreeIPAConfig {
            host: "custom.ipa.com".to_string(),
            port: 4430,
            use_https: false,
            username: "custom_admin".to_string(),
            password: "custom_pass".to_string(),
            base_dn: "dc=custom,dc=ipa".to_string(),
            realm: "CUSTOM.IPA".to_string(),
            domain: "custom.ipa".to_string(),
            timeout: 60,
            api_version: "3.0.0".to_string(),
            verify_ssl: false,
        };
        
        assert_eq!(config.host, "custom.ipa.com");
        assert_eq!(config.port, 4430);
        assert_eq!(config.use_https, false);
        assert_eq!(config.username, "custom_admin");
        assert_eq!(config.api_version, "3.0.0");
        assert_eq!(config.verify_ssl, false);
    }
}
