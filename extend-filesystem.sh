#!/bin/bash
# Script to extend filesystem after disk expansion
# Run this on each worker node after expanding the virtual disk

echo "🔧 Extending filesystem after disk expansion..."

# Check current disk layout
echo "📊 Current disk layout:"
lsblk
df -h /

# Extend the partition (assuming /dev/sda1)
echo "📈 Extending partition..."
sudo growpart /dev/sda 1

# Resize the filesystem
echo "📈 Resizing filesystem..."
sudo resize2fs /dev/sda1

# Verify the changes
echo "✅ Verification:"
df -h /
lsblk

echo "🎉 Filesystem extension completed!"