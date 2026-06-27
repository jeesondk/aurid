//! Active Directory integration module
//! 
//! Handles LDAP connection and data extraction from Active Directory

use anyhow::{Context, Result};
use ldap3::{Ldap, LdapConn, Scope, SearchEntry};
use std::time::Duration;

use crate::config::Config;

/// LDAP connection wrapper
pub struct AdConnection {
    ldap: Ldap,
    config: Config,
}

impl AdConnection {
    /// Create a new AD connection
    pub async fn new(config: &Config) -> Result<Self> {
        let host = &config.active_directory.host;
        let port = config.active_directory.port;
        
        let ldap = Ldap::new(host, port, if config.active_directory.use_ssl {
            LdapConn::Tls
        } else {
            LdapConn::Plain
        })?;
        
        Ok(Self {
            ldap,
            config: config.clone(),
        })
    }

    /// Test the LDAP connection
    pub async fn test_connection(&self) -> Result<()> {
        let mut conn = self.ldap.connect()?;
        conn.simple_bind(
            &self.config.active_directory.bind_dn,
            &self.config.active_directory.bind_password
        )?.success()?;
        Ok(())
    }

    /// Search for users in AD
    pub async fn search_users(&self, filter: &str) -> Result<Vec<SearchEntry>> {
        let mut conn = self.ldap.connect()?;
        conn.simple_bind(
            &self.config.active_directory.bind_dn,
            &self.config.active_directory.bind_password
        )?.success()?;
        
        let (rs, _res) = conn.search(
            &self.config.active_directory.base_dn,
            Scope::Sub,
            filter,
            vec!["*"]
        )?;
        
        let entries: Vec<SearchEntry> = rs.collect();
        Ok(entries)
    }
}

/// Validate AD connection and data
pub async fn validate(config: &Config, connection_only: bool, sample_size: usize) -> Result<()> {
    let conn = AdConnection::new(config).await?;
    conn.test_connection().await?;
    
    if !connection_only {
        // Sample validation
        let users = conn.search_users("(objectClass=user)").await?;
        println!("Found {} users in AD", users.len());
        
        if users.len() < sample_size {
            println!("Warning: Found fewer users than sample size");
        }
    }
    
    Ok(())
}

/// Export data from Active Directory
pub async fn export_data(
    config: &Config,
    output_path: &std::path::Path,
    format: &str,
    ou_filter: Option<String>,
    group_filter: Option<String>,
) -> Result<()> {
    let conn = AdConnection::new(config).await?;
    
    // For now, just export a simple message
    let data = "AD Export Data";
    std::fs::write(output_path, data)?;
    
    Ok(())
}
