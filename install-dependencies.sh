#!/usr/bin/env bash
set -euo pipefail

echo "==> Updating package lists"
sudo apt-get update

echo "==> Installing OpenJDK 21"
sudo apt-get install -y openjdk-21-jdk

echo "==> Verifying Java installation"
java -version

echo "==> All dependencies installed successfully"
