#!/bin/bash

# Script to create the complete installation package
# Run this to generate all files in the correct structure

set -e

PACKAGE_DIR="rpi-setup-package"

echo "Creating installation package directory: $PACKAGE_DIR"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR/modules"

echo "Creating main installation scripts..."

# Copy or create all the files (you would paste the content of each file here)

echo "Installation package created in: $PACKAGE_DIR"
echo ""
echo "To use this package:"
echo "1. Copy the entire '$PACKAGE_DIR' directory to your Raspberry Pi"
echo "2. cd $PACKAGE_DIR"
echo "3. chmod +x install-local.sh"
echo "4. ./install-local.sh"
echo ""
echo "Or zip it for easy transfer:"
echo "zip -r rpi-setup.zip $PACKAGE_DIR"