use clap::{Parser, Subcommand};

mod config;
mod issue;
mod template;

#[derive(Parser)]
#[command(name = "qatool", about = "CL8Y Ecosystem QA Tool")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Detect project and create .qatool.toml
    Init,
    /// QA test pass operations
    Pass {
        #[command(subcommand)]
        action: PassAction,
    },
    /// File a bug issue on GitLab
    Bug {
        /// Bug description
        description: String,
        /// Path to evidence screenshot
        #[arg(short, long)]
        evidence: Option<String>,
    },
    /// Generate QA summary report
    Report,
}

#[derive(Subcommand)]
enum PassAction {
    /// Generate new QA pass from template
    New,
    /// Upload completed pass to GitLab
    Upload {
        /// Path to completed pass file
        file: String,
    },
}

fn main() {
    let cli = Cli::parse();

    match cli.command {
        Commands::Init => config::init(),
        Commands::Pass { action } => match action {
            PassAction::New => template::new_pass(),
            PassAction::Upload { file } => template::upload_pass(&file),
        },
        Commands::Bug { description, evidence } => {
            issue::file_bug(&description, evidence.as_deref());
        }
        Commands::Report => {
            println!("Generating QA report...");
            println!("TODO: read passes, count PASS/FAIL/SKIP");
        }
    }
}
