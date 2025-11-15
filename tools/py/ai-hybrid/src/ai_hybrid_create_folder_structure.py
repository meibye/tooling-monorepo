#!/usr/bin/env python3

import argparse
import os


def create_dirs(root: str, dirs: list):
    for d in dirs:
        path = os.path.join(root, d)
        if not os.path.exists(path):
            os.makedirs(path, exist_ok=True)
            print(f"Created directory: {path}")
        else:
            print(f"Directory already exists: {path}")


def create_empty_files(root: str, files: list):
    for f in files:
        path = os.path.join(root, f)
        dirpath = os.path.dirname(path)
        if not os.path.exists(dirpath):
            os.makedirs(dirpath, exist_ok=True)
            print(f"Created parent directory for file: {dirpath}")
        if not os.path.exists(path):
            with open(path, "w", encoding="utf-8") as fp:
                fp.write("")  # create empty file
            print(f"Created file: {path}")
        else:
            print(f"File already exists: {path}")


def main():
    parser = argparse.ArgumentParser(
        description="Create folder structure for hybrid Neo4j + Qdrant backend solution."
    )
    parser.add_argument(
        "root", help="Root path where folder structure will be created."
    )
    args = parser.parse_args()
    root = args.root

    # Define required sub-directories relative to root
    directories = ["backend", "backend/models", "data", "scripts", "logs"]

    # Define base files to create (paths relative to root)
    files = [
        "backend/Dockerfile",
        "backend/requirements.txt",
        "backend/ai_hybrid_app_import_sync.py",
        "backend/app.py",
        "scripts/setup-wrapper.ps1",
        "scripts/install_hybrid.sh",
        "data/sample-data.json",
        "logs/.gitkeep",
    ]

    print(f"Creating folder structure under root: {root}")
    create_dirs(root, directories)
    create_empty_files(root, files)
    print("Folder structure creation complete.")


if __name__ == "__main__":
    main()
