use serde::{Deserialize, Serialize};
use std::fs;
use std::process::Command;

#[derive(Debug, Serialize, Deserialize)]
pub struct QaConfig {
    pub project: ProjectConfig,
    pub ecosystem: EcosystemConfig,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ProjectConfig {
    pub name: String,
    pub gitlab_repo: String,
    pub qa_issue: Option<u32>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct EcosystemConfig {
    pub repo: String,
    pub local_path: String,
}

/// Known projects and their detection patterns
const KNOWN_PROJECTS: &[(&str, &str, &str)] = &[
    ("cl8y-bridge-monorepo", "PlasticDigits/cl8y-bridge-monorepo", "packages/frontend"),
    ("cl8y-dex-terraclassic", "PlasticDigits/cl8y-dex-terraclassic", "smartcontracts"),
    ("ustr-cmm", "PlasticDigits/ustr-cmm", ""),
];

pub fn detect_project() -> Option<(&'static str, &'static str)> {
    let output = Command::new("git")
        .args(["remote", "get-url", "origin"])
        .output()
        .ok()?;
    let remote = String::from_utf8_lossy(&output.stdout);

    for (name, repo, _marker) in KNOWN_PROJECTS {
        if remote.contains(repo) {
            return Some((name, repo));
        }
    }
    None
}

pub fn init() {
    match detect_project() {
        Some((name, repo)) => {
            println!("Detected project: {}", name);
            println!("GitLab repo: {}", repo);

            let config = QaConfig {
                project: ProjectConfig {
                    name: name.to_string(),
                    gitlab_repo: repo.to_string(),
                    qa_issue: None,
                },
                ecosystem: EcosystemConfig {
                    repo: "https://gitlab.com/PlasticDigits/cl8y-ecosystem-qa.git".to_string(),
                    local_path: "~/cl8y-ecosystem-qa".to_string(),
                },
            };

            let toml_str = toml::to_string_pretty(&config).expect("Failed to serialize config");
            fs::write(".qatool.toml", &toml_str).expect("Failed to write .qatool.toml");
            println!("Created .qatool.toml");
        }
        None => {
            eprintln!("Could not detect project. Run this inside a known CL8Y repo.");
            eprintln!("Or create .qatool.toml manually.");
        }
    }
}
