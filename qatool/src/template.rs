use chrono::Local;
use std::fs;
use std::path::Path;

use crate::config;

pub fn new_pass() {
    let project = match config::detect_project() {
        Some((name, _)) => name.to_string(),
        None => {
            eprintln!("Could not detect project. Run qatool init first.");
            return;
        }
    };

    let ecosystem_path = dirs_or_default();
    let template_dir = format!("{}/projects/{}/templates", ecosystem_path, project);

    let templates: Vec<_> = fs::read_dir(&template_dir)
        .map(|entries| {
            entries
                .filter_map(|e| e.ok())
                .filter(|e| e.path().extension().map_or(false, |ext| ext == "md"))
                .collect()
        })
        .unwrap_or_default();

    if templates.is_empty() {
        eprintln!("No templates found in {}", template_dir);
        return;
    }

    let template_path = &templates[0].path();
    let template = fs::read_to_string(template_path).expect("Failed to read template");

    let date = Local::now().format("%Y-%m-%d").to_string();
    let filename = format!("QA_PASS_{}.md", date);

    let filled = template
        .replace("• ", &format!("• {}\n", date))
        .replace("| QA Tester | | | |", &format!("| QA Tester | @Brouie | {} | |", date));

    fs::write(&filename, &filled).expect("Failed to write pass file");
    println!("Created: {}", filename);
    println!("Template: {}", template_path.display());
}

pub fn upload_pass(file: &str) {
    if !Path::new(file).exists() {
        eprintln!("File not found: {}", file);
        return;
    }

    let project = match config::detect_project() {
        Some((name, _)) => name.to_string(),
        None => {
            eprintln!("Could not detect project.");
            return;
        }
    };

    // Copy to ecosystem repo
    let ecosystem_path = dirs_or_default();
    let dest = format!("{}/projects/{}/passes/{}", ecosystem_path, project, file);
    fs::copy(file, &dest).unwrap_or_else(|_| {
        eprintln!("Warning: could not copy to ecosystem repo at {}", dest);
        0
    });

    println!("Pass file ready: {}", file);
    println!("TODO: Upload to GitLab tracking issue via glab");
}

fn dirs_or_default() -> String {
    std::env::var("QATOOL_ECOSYSTEM_PATH")
        .unwrap_or_else(|_| {
            let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
            format!("{}/cl8y-ecosystem-qa", home)
        })
}
