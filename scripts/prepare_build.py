#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import shutil
import glob
from pathlib import Path

# Configuration
CONFIG_PATH = Path("config/services.json")
WORKSPACE_ROOT = Path.cwd()
INIT_SCRIPTS_DIR = WORKSPACE_ROOT / "docker/init-scripts"

def load_config():
    with open(CONFIG_PATH, 'r') as f:
        return json.load(f)

def run_command(command, cwd=None, check=True):
    try:
        subprocess.run(
            command, 
            cwd=cwd, 
            check=check, 
            shell=True, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE,
            text=True
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Error running command: {command}")
        print(f"   Output: {e.stderr}")
        return False

def get_target_branch(repo_config):
    # Check environment variable first
    env_var = repo_config.get("env_var")
    if env_var and os.environ.get(env_var):
        return os.environ.get(env_var)
    return repo_config["default_branch"]

def clean_init_scripts():
    print("\nCleaning up old init scripts...")
    # Create directory if it doesn't exist
    INIT_SCRIPTS_DIR.mkdir(parents=True, exist_ok=True)
    
    # Remove all SQL files that start with a number >= 10
    # We preserve 00-09 for platform-level scripts
    for file_path in INIT_SCRIPTS_DIR.glob("*.sql"):
        if file_path.name[:2].isdigit() and int(file_path.name[:2]) >= 10:
            print(f"   Removing {file_path.name}")
            file_path.unlink()

def copy_repo_init_scripts(repo_path, repo_name, counter):
    # Define potential locations for init scripts in the repo
    # Priority: docker/init.sql, sql/init.sql, *.sql in root
    potential_paths = [
        repo_path / "docker/init.sql",
        repo_path / "sql/init.sql",
        repo_path / "init.sql"
    ]
    
    found = False
    for src_path in potential_paths:
        if src_path.exists():
            dest_name = f"{counter:02d}-{repo_name}.sql"
            dest_path = INIT_SCRIPTS_DIR / dest_name
            print(f"   Found init script: {src_path.relative_to(repo_path)}")
            print(f"   Copying to {dest_path.relative_to(WORKSPACE_ROOT)}")
            shutil.copy2(src_path, dest_path)
            found = True
            break # Stop after finding the first match
            
    if not found:
        print(f"   No init script found in standard locations for {repo_name}")
    
    return found

def prepare_repo(key, config, script_counter):
    print(f"\nProcessing {config['name']}...")
    
    repo_path = WORKSPACE_ROOT / config["path"]
    target_branch = get_target_branch(config)
    
    # 1. Clone if not exists
    if not repo_path.exists():
        print(f"   Cloning from {config['url']}...")
        parent_dir = repo_path.parent
        parent_dir.mkdir(parents=True, exist_ok=True)
        
        if not run_command(f"git clone {config['url']} {repo_path.name}", cwd=parent_dir):
            return False
    else:
        print(f"   Repo exists at {config['path']}")

    # 2. Fetch latest
    print("   Fetching latest changes...")
    if not run_command("git fetch --all", cwd=repo_path):
        return False

    # 3. Checkout target branch
    print(f"   Checking out branch: {target_branch}")
    # Try simple checkout first (local or remote tracking)
    if not run_command(f"git checkout {target_branch}", cwd=repo_path, check=False):
        print(f"   [WARN] Could not checkout {target_branch}, trying to create from origin...")
        # Try to checkout remote branch explicitly
        if not run_command(f"git checkout -b {target_branch} origin/{target_branch}", cwd=repo_path, check=False):
             print(f"   [ERROR] Failed to checkout {target_branch}. Please check if the branch exists.")
             return False

    # 4. Pull latest
    print(f"   Pulling latest for {target_branch}...")
    run_command(f"git pull origin {target_branch}", cwd=repo_path, check=False)
    
    print(f"   [OK] Ready on branch: {target_branch}")
    
    # 5. Copy init scripts
    copy_repo_init_scripts(repo_path, config["name"], script_counter)
    
    return True

def main():
    print("TeaPot CI/CD Preparation Tool")
    print("================================")
    
    if not CONFIG_PATH.exists():
        print(f"[ERROR] Config file not found at {CONFIG_PATH}")
        sys.exit(1)
        
    config = load_config()
    success = True
    
    clean_init_scripts()
    
    # Start counter at 10 to avoid conflict with base scripts
    script_counter = 10
    
    for key, repo_config in config["repositories"].items():
        if prepare_repo(key, repo_config, script_counter):
            script_counter += 1
        else:
            success = False
            print(f"[ERROR] Failed to prepare {key}")
    
    if success:
        print("\nAll repositories prepared successfully!")
        sys.exit(0)
    else:
        print("\n[WARN] Some repositories failed to prepare.")
        sys.exit(1)

if __name__ == "__main__":
    main()
