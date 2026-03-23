#!/bin/bash
# decrypt-note.sh - Decrypt an encrypted file using OpenSSL AES-256-CBC
# Usage: ./decrypt-note.sh <file.enc>
# Creates: <file> (decrypted version)
# Removes: <file.enc> (encrypted version)

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if file argument provided
if [ $# -ne 1 ]; then
    echo -e "${RED}Error: Missing file argument${NC}"
    echo "Usage: $0 <file.enc>"
    echo "Example: $0 ~/Water/Fire/Archive/account.md.enc"
    exit 1
fi

INPUT_FILE="$1"

# Check if input file has .enc extension
if [[ ! "$INPUT_FILE" =~ \.enc$ ]]; then
    echo -e "${RED}Error: File must have .enc extension${NC}"
    echo "Got: $INPUT_FILE"
    exit 1
fi

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: File not found: $INPUT_FILE${NC}"
    exit 1
fi

# Remove .enc extension to get output filename
OUTPUT_FILE="${INPUT_FILE%.enc}"

# Check if output file already exists
if [ -f "$OUTPUT_FILE" ]; then
    echo -e "${YELLOW}Warning: Decrypted file already exists: $OUTPUT_FILE${NC}"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo -e "${GREEN}Decrypting: $INPUT_FILE${NC}"
echo -e "${GREEN}Output to: $OUTPUT_FILE${NC}"
echo

# Prompt for password (hidden input)
read -s -p "Enter decryption password: " PASSWORD
echo

# Check if password is not empty
if [ -z "$PASSWORD" ]; then
    echo -e "${RED}Error: Password cannot be empty${NC}"
    exit 1
fi

# Decrypt the file using OpenSSL
# -d: Decrypt mode
# -aes-256-cbc: AES 256-bit encryption in CBC mode
# -pbkdf2: Use PBKDF2 key derivation
# -iter 100000: 100,000 iterations for key derivation
if openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
    -in "$INPUT_FILE" -out "$OUTPUT_FILE" -pass pass:"$PASSWORD" 2>/dev/null; then
    
    echo -e "${GREEN}✓ Decryption successful!${NC}"
    
    # Remove the encrypted file
    echo -e "${YELLOW}Removing encrypted file...${NC}"
    rm "$INPUT_FILE"
    echo -e "${GREEN}✓ Encrypted file removed${NC}"
    
    echo
    echo -e "${GREEN}Done! Decrypted file: $OUTPUT_FILE${NC}"
    echo -e "${YELLOW}Warning: This file contains sensitive data!${NC}"
    echo -e "${YELLOW}Remember to encrypt it again before syncing to git${NC}"
    
else
    echo -e "${RED}✗ Decryption failed${NC}"
    echo -e "${RED}Wrong password or corrupted file${NC}"
    # Don't remove the encrypted file on failure
    exit 1
fi
