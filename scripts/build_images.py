#!/usr/bin/env python3
"""
Build and tag images for the platform.

Usage:
  python3 scripts/build_images.py --builders   # build all builder images
  python3 scripts/build_images.py --deploys    # build deployable images (tag :latest)
  python3 scripts/build_images.py --all        # build both

The script reads `images.json` at repo root.
For `postgres` deploy image it will run `prepare_build.py` first to collect SQLs.
"""
import argparse
import json
import os
import subprocess
from pathlib import Path

ROOT = Path.cwd()
IMAGES_FILE = ROOT / "images.json"
PREPARE_SCRIPT = ROOT / "scripts/prepare_build.py"


def run(cmd, cwd=None, check=True):
    print(f"$ {cmd}")
    res = subprocess.run(cmd, shell=True, cwd=cwd)
    if check and res.returncode != 0:
        raise SystemExit(res.returncode)


def load_images():
    with open(IMAGES_FILE, 'r') as f:
        return json.load(f)


def build_builder_image(name, image_name):
    dockerfile = ROOT / f"docker/{name}-builder.Dockerfile"
    if not dockerfile.exists():
        print(f"[WARN] Builder Dockerfile not found for {name}: {dockerfile}")
        return
    tag = f"{image_name}:latest"
    run(f"docker build -f {dockerfile} -t {tag} .")


def build_deploy_image(name, image_name):
    # For postgres, ensure SQLs are collected
    if name == 'postgres' and PREPARE_SCRIPT.exists():
        print("Preparing repositories and collecting SQL scripts before building postgres image...")
        run(f"python3 {PREPARE_SCRIPT}")

    dockerfile = ROOT / f"docker/{name}.Dockerfile"
    if not dockerfile.exists():
        print(f"[WARN] Deploy Dockerfile not found for {name}: {dockerfile}")
        return
    
    # Determine build context
    # user-service needs to be built from its repo directory
    if name == 'user-service':
        context = ROOT / "repos/teapot-user-service"
        # Generate code if Makefile exists
        makefile = context / "Makefile"
        if makefile.exists():
            print("Generating code for user-service...")
            run("make generate", cwd=context, check=False)
        
        # Use relative path to Dockerfile from repo root
        dockerfile_rel = f"../../docker/{name}.Dockerfile"
        tag = f"{image_name}:latest"
        run(f"docker build -f {dockerfile_rel} -t {tag} .", cwd=context)
    else:
        # For postgres, redis, etc., build from repo root
        tag = f"{image_name}:latest"
        run(f"docker build -f {dockerfile} -t {tag} .")


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--builders', action='store_true')
    p.add_argument('--deploys', action='store_true')
    p.add_argument('--all', action='store_true')
    args = p.parse_args()

    if not IMAGES_FILE.exists():
        print(f"images.json not found at {IMAGES_FILE}")
        raise SystemExit(1)

    imgs = load_images().get('services', {})

    if not (args.builders or args.deploys or args.all):
        p.print_help()
        return

    if args.builders or args.all:
        print("Building builder images...")
        for name, info in imgs.items():
            build_image = info.get('build_image')
            if build_image:
                build_builder_image(name, build_image)

    if args.deploys or args.all:
        print("Building deployable images...")
        for name, info in imgs.items():
            deploy_image = info.get('deploy_image')
            if deploy_image:
                build_deploy_image(name, deploy_image)


if __name__ == '__main__':
    main()
