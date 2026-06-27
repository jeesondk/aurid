//! Data models for migration
//! 
//! Defines the data structures used in migration

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// AD User representation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AdUser {
    pub username: String,
    pub first_name: String,
    pub last_name: String,
    pub email: Option<String>,
    pub distinguished_name: String,
    pub groups: Vec<String>,
    pub enabled: bool,
}

/// AD Group representation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AdGroup {
    pub name: String,
    pub distinguished_name: String,
    pub members: Vec<String>,
    pub description: Option<String>,
}

/// FreeIPA User representation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FreeIpaUser {
    pub username: String,
    pub first_name: String,
    pub last_name: String,
    pub email: Option<String>,
    pub uid: u32,
    pub gid: u32,
    pub home_directory: String,
    pub shell: String,
}

/// FreeIPA Group representation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FreeIpaGroup {
    pub name: String,
    pub gid: u32,
    pub members: Vec<String>,
    pub description: Option<String>,
}

/// Migration result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MigrationResult {
    pub users_created: usize,
    pub users_updated: usize,
    pub users_failed: usize,
    pub groups_created: usize,
    pub groups_updated: usize,
    pub groups_failed: usize,
    pub errors: HashMap<String, String>,
    pub start_time: String,
    pub end_time: String,
}

impl Default for MigrationResult {
    fn default() -> Self {
        Self {
            users_created: 0,
            users_updated: 0,
            users_failed: 0,
            groups_created: 0,
            groups_updated: 0,
            groups_failed: 0,
            errors: HashMap::new(),
            start_time: String::new(),
            end_time: String::new(),
        }
    }
}
