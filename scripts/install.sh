#!/usr/bin/env bash

set -e # Stop on error

# --- Configuration ---
REPO_URL="https://github.com/0Sycamores/nixos-config"
TARGET_DIR="/tmp/nixos-install"

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== NixOS Multi-Host Installer ===${NC}"

# --- 1. Prepare Environment ---
echo -e "\n${GREEN}[1/7] Preparing environment...${NC}"

# Check if in NixOS installation environment
if [ ! -e /etc/NIXOS ]; then
    echo -e "${RED}Warning: It seems you are not in the NixOS ISO environment. This script is intended for bare metal installation.${NC}"
    echo -ne "Confirm to continue? (yes/no): "
    read CONFIRM
    if [ "$CONFIRM" != "yes" ]; then exit 1; fi
fi

# Check network
if ping -c 1 baidu.com &> /dev/null; then
    echo "Internet connection is normal."
else
    echo -e "${RED}Unable to connect to the internet. Please configure the network first (nmcli / wpa_supplicant).${NC}"
    exit 1
fi

# Ask to configure HTTP proxy
echo -e "\nDo you need to configure an HTTP proxy to speed up GitHub access?"
echo -ne "Please enter proxy address (e.g. http://192.168.1.100:7890, leave empty to skip): "
read PROXY_ADDR

if [ -n "$PROXY_ADDR" ]; then
    export http_proxy="$PROXY_ADDR"
    export https_proxy="$PROXY_ADDR"
    echo "Proxy set: $PROXY_ADDR"
fi

# Enable Flakes
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf << EOF
experimental-features = nix-command flakes
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/
EOF

# --- 2. Fetch Configuration ---
echo -e "\n${GREEN}[2/7] Fetching configuration...${NC}"

echo "Preparing to clone configuration from GitHub..."
if [ -d "$TARGET_DIR" ]; then
    echo "Cleaning up old directory $TARGET_DIR ..."
    rm -rf $TARGET_DIR
fi

# Use git clone to pull code
nix shell nixpkgs#git --command git clone $REPO_URL $TARGET_DIR
cd $TARGET_DIR

# --- 3. Select Host ---
echo -e "\n${GREEN}[3/7] Select target host${NC}"
echo "Available host configurations (hosts/):"

# Get subdirectories in hosts directory
HOSTS=($(ls hosts))

# Show menu
i=1
for host in "${HOSTS[@]}"; do
    echo "$i) $host"
    let i++
done

echo -ne "Please enter the number to select a host: "
read HOST_INDEX

# Validate input
if [[ ! "$HOST_INDEX" =~ ^[0-9]+$ ]] || [ "$HOST_INDEX" -lt 1 ] || [ "$HOST_INDEX" -gt "${#HOSTS[@]}" ]; then
    echo -e "${RED}Error: Invalid selection${NC}"
    exit 1
fi

# Get selected hostname
SELECTED_HOST=${HOSTS[$((HOST_INDEX-1))]}
echo -e "Selected host: ${GREEN}$SELECTED_HOST${NC}"

# Check if disko configuration exists
if [ ! -f "hosts/$SELECTED_HOST/disko.nix" ]; then
    echo -e "${RED}Error: hosts/$SELECTED_HOST/disko.nix does not exist.${NC}"
    echo "This host might not support automatic partitioning installation, or configuration is incomplete."
    exit 1
fi

# --- 4. Select Disk ---
echo -e "\n${GREEN}[4/7] Select target disk${NC}"
lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep "disk"
echo -ne "Please enter target disk name (e.g., sda or nvme0n1): "
read DISK_NAME
TARGET_DISK="/dev/$DISK_NAME"

if [ ! -b "$TARGET_DISK" ]; then
    echo -e "${RED}Error: Device $TARGET_DISK not found${NC}"
    exit 1
fi

echo -e "${RED}Warning: All data on $TARGET_DISK will be cleared!${NC}"
echo -ne "Confirm to continue? (yes/no): "
read CONFIRM_DISK
if [ "$CONFIRM_DISK" != "yes" ]; then
    echo "Cancelled."
    exit 1
fi

# --- 5. Inject Configuration ---
echo -e "\n${GREEN}[5/7] Injecting hardware configuration...${NC}"

# Modify disk device in Disko configuration
# Match device = "..."; and replace
sed -i "s|device = \".*\";|device = \"$TARGET_DISK\";|" hosts/$SELECTED_HOST/disko.nix
echo "Installation target set to $TARGET_DISK"

# --- 6. Partitioning and Formatting ---
echo -e "\n${GREEN}[6/7] Executing Disko partitioning...${NC}"
nix run .#disko -- --mode disko ./hosts/$SELECTED_HOST/disko.nix

# --- 7. Install ---
echo -e "\n${GREEN}[7/7] Generating hardware config and installing...${NC}"

# Generate hardware-configuration.nix
nixos-generate-config --root /mnt --no-filesystems --show-hardware-config > hosts/$SELECTED_HOST/hardware.nix
git add hosts/$SELECTED_HOST/hardware.nix

echo "Starting NixOS installation ($SELECTED_HOST)..."
nixos-install --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" --root /mnt --flake .#$SELECTED_HOST

echo -e "\n${GREEN}=== Installation Complete! ===${NC}"
echo "Please set root password:"
nixos-enter --root /mnt -c 'passwd root'

echo -e "\n${GREEN}You can type 'reboot' to restart into the new system.${NC}"