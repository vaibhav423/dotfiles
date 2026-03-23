#!/bin/bash
# encrypt-note.sh - Encrypt a file using OpenSSL AES-256-CBC
# Usage: ./encrypt-note.sh <file>
# Creates: <file>.enc (encrypted version)
# Removes: <file> (original unencrypted)

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if file argument provided
if [ $# -ne 1 ]; then
    echo -e "${RED}Error: Missing file argument${NC}"
    echo "Usage: $0 <file>"
    echo "Example: $0 ~/Water/Fire/Archive/account.md"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${INPUT_FILE}.enc"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: File not found: $INPUT_FILE${NC}"
    exit 1
fi

# Check if output file already exists
if [ -f "$OUTPUT_FILE" ]; then
    echo -e "${YELLOW}Warning: Encrypted file already exists: $OUTPUT_FILE${NC}"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo -e "${GREEN}Encrypting: $INPUT_FILE${NC}"
echo -e "${GREEN}Output to: $OUTPUT_FILE${NC}"
echo

# Prompt for password (hidden input)
read -s -p "Enter encryption password: " PASSWORD
echo
read -s -p "Confirm password: " PASSWORD_CONFIRM
echo

# Check if passwords match
if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo -e "${RED}Error: Passwords do not match${NC}"
    exit 1
fi

# Check if password is not empty
if [ -z "$PASSWORD" ]; then
    echo -e "${RED}Error: Password cannot be empty${NC}"
    exit 1
fi

# Encrypt the file using OpenSSL
# -aes-256-cbc: AES 256-bit encryption in CBC mode
# -pbkdf2: Use PBKDF2 key derivation
# -iter 100000: 100,000 iterations for key derivation
# -salt: Add random salt
if openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt \
    -in "$INPUT_FILE" -out "$OUTPUT_FILE" -pass pass:"$PASSWORD"; then
    
    echo -e "${GREEN}✓ Encryption successful!${NC}"
    
    # Remove the original unencrypted file
    echo -e "${YELLOW}Removing original unencrypted file...${NC}"
    rm "$INPUT_FILE"
    echo -e "${GREEN}✓ Original file removed${NC}"
    
    echo
    echo -e "${GREEN}Done! Encrypted file: $OUTPUT_FILE${NC}"
    echo -e "${YELLOW}Remember: The original file has been deleted${NC}"
    
else
    echo -e "${RED}✗ Encryption failed${NC}"
    exit 1
fi
