use std::process::Command;
use crate::config;

/// File a bug issue on GitLab via glab CLI
pub fn file_bug(description: &str, evidence: Option<&str>) {
    let (project_name, gitlab_repo) = match config::detect_project() {
        Some(p) => p,
        None => {
            eprintln!("Could not detect project. Run qatool init first.");
            return;
        }
    };

    println!("Filing bug for: {}", project_name);
    println!("Description: {}", description);

    // Build the issue title
    let title = format!("bug: {}", description);

    // Build the issue body
    let mut body = format!(
        "## Description\n\n{}\n\n## Environment\n\n- Filed via qatool\n- Project: {}\n",
        description, project_name
    );

    if let Some(ev_path) = evidence {
        body.push_str(&format!("\n## Evidence\n\nAttached: {}\n", ev_path));
    }

    body.push_str("\n## Steps to Reproduce\n\n1. \n2. \n3. \n");

    // Call glab to create the issue
    let mut args = vec![
        "issue".to_string(),
        "create".to_string(),
        "-R".to_string(),
        gitlab_repo.to_string(),
        "-t".to_string(),
        title,
        "-d".to_string(),
        body,
        "-l".to_string(),
        "bug".to_string(),
    ];

    println!("Creating issue on {}...", gitlab_repo);

    let output = Command::new("glab")
        .args(&args)
        .output();

    match output {
        Ok(result) => {
            let stdout = String::from_utf8_lossy(&result.stdout);
            let stderr = String::from_utf8_lossy(&result.stderr);
            if result.status.success() {
                println!("{}", stdout);
                // Copy evidence to ecosystem repo if provided
                if let Some(ev_path) = evidence {
                    copy_evidence(project_name, ev_path);
                }
            } else {
                eprintln!("glab error: {}", stderr);
            }
        }
        Err(e) => {
            eprintln!("Failed to run glab: {}. Is glab installed?", e);
        }
    }
}

/// Copy evidence file to ecosystem QA repo
fn copy_evidence(project_name: &str, evidence_path: &str) {
    let ecosystem_path = std::env::var("QATOOL_ECOSYSTEM_PATH")
        .unwrap_or_else(|_| {
            let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
            format!("{}/cl8y-ecosystem-qa", home)
        });

    let dest_dir = format!("{}/projects/{}/evidence", ecosystem_path, project_name);
    let _ = std::fs::create_dir_all(&dest_dir);

    let filename = std::path::Path::new(evidence_path)
        .file_name()
        .unwrap_or_default()
        .to_string_lossy();

    let timestamp = chrono::Local::now().format("%Y%m%d-%H%M%S");
    let dest = format!("{}/{}_{}", dest_dir, timestamp, filename);

    match std::fs::copy(evidence_path, &dest) {
        Ok(_) => println!("Evidence copied to: {}", dest),
        Err(e) => eprintln!("Warning: could not copy evidence: {}", e),
    }
}
