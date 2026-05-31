# AWS EC2 EBS Volume Management & LVM Configuration Guide

This repository contains a step-by-step technical log and documentation for provisioning, attaching, and managing Amazon EBS volumes on an AWS EC2 Ubuntu instance using both standard disk formatting and **Logical Volume Management (LVM)**.

---

## 🏗️ Storage Infrastructure & Topology

The environment is built by attaching three distinct EBS block storage volumes to a single EC2 instance alongside the default root OS drive.

*   **Initial Volumes Created & Attached via AWS Console:**
    *   `EBS Volume 1`: **10 GB** (Discovered in OS as `/dev/nvme1n1`)
    *   `EBS Volume 2`: **8 GB**  (Discovered in OS as `/dev/nvme2n1`)
    *   `EBS Volume 3`: **12 GB** (Discovered in OS as `/dev/nvme3n1`)
*   **Operating System Volume:**
    *   `/dev/nvme0n1` (**20 GB**) ➔ AWS Default Ubuntu OS Root Volume

---

## 🛠️ Step-by-Step Implementation Guide

### Phase 1: Initial LVM Clustering and Formatting

#### 1. Privilege Escalation
LVM administration requires root-level kernel permissions. Switch to the superuser account before execution:
```bash
sudo su
```

#### 2. Initialize Physical Volumes (PV)
Initialize the raw EBS block storage devices into LVM physical volumes. This writes the necessary tracking metadata onto the disks:
```bash
pvcreate /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1
```

#### 3. Create the Volume Group (VG)
Combine the first two physical volumes (`/dev/nvme1n1` and `/dev/nvme2n1`) into a single virtual storage pool named `rdn`:
```bash
vgcreate rdn /dev/nvme1n1 /dev/nvme2n1
```
*Note: This creates an aggregate virtual pool with a capacity of ~17.99 GiB.*

#### 4. Allocate a Logical Volume (LV)
Carve out an initial 10 GB partition named `rdn_adn` from the `rdn` volume group pool:
```bash
lvcreate -L 10G -n rdn_adn rdn
```

#### 5. Format and Mount the Logical Volume
Format the LVM partition with an `ext4` high-performance filesystem, build a target directory, and mount it:
```bash
mkfs.ext4 /dev/rdn/rdn_adn
mkdir /mnt/rdn_lv_mont
mount /dev/rdn/rdn_adn /mnt/rdn_lv_mont
```

#### 6. File Persistence Verification Testing
Verify that data survives mounting cycles. Create a test file, unmount the drive, observe its deliberate absence, and remount it to verify data integrity:
```bash
# Create and populate a test file
cd /mnt/rdn_lv_mont
mkdir devops
echo "hiiiiiiiiiiiiiiiiii" > hello.txt

# Unmount the storage abstraction layer
cd ~
umount /mnt/rdn_lv_mont
cat /mnt/rdn_lv_mont/hello.txt  # Returns: No such file or directory (Expected behavior)

# Remount to verify files remain safe on the hardware backing store
mount /dev/rdn/rdn_adn /mnt/rdn_lv_mont
cat /mnt/rdn_lv_mont/hello.txt  # Returns: hiiiiiiiiiiiiiiiiii (Data Verified!)
```

---

### Phase 2: Standalone Drive Formatting & LVM Expansion (Continuation of Work)

#### 1. Format the 12 GB Spare Disk Separately
Your third EBS volume (`/dev/nvme3n1`) was originally marked as an LVM physical volume. To use it instead as a standalone raw storage disk, overwrite its LVM signatures by formatting it directly with its own `ext4` filesystem:

```bash
mkfs -t ext4 /dev/nvme3n1
```
*Note: The system will notice it contains an LVM metadata signature and prompt: `Proceed anyway? (y,N)`. Type `y` to force overwrite.*

#### 2. Create Mount Point and Bind the Standalone Disk
Create a separate target path directory under `/mnt` and mount the standalone 12 GB drive to it:
```bash
mkdir /mnt/rdn_disk_mount
mount /dev/nvme3n1 /mnt/rdn_disk_mount
```

Verify the storage block layouts using `lsblk` and `df -h`. You will observe two distinct mounted active filesystems running simultaneously:
*   `/dev/mapper/rdn-rdn_adn` (LVM Volume) ➔ Mounted at `/mnt/rdn_lv_mont`
*   `/dev/nvme3n1` (Standard Disk) ➔ Mounted at `/mnt/rdn_disk_mount`

#### 3. Dynamically Extend the LVM Volume (On-The-Fly Resizing)
The remaining free space in the `rdn` Volume Group (~7.99 GiB) can be added to your logical volume without losing data. 

Attempting to allocate a full `+8G` directly will fail due to exact byte physical extent alignments (`Insufficient free space`). Instead, allocate `+7.9G` to max out your current pooling space:

```bash
# Open the LVM configuration utility or execute directly:
lvextend -L +7.9G /dev/rdn/rdn_adn
```

#### 4. Confirm the Expanded Storage Architecture
Run `lvdisplay` or `lsblk` to verify the new capacity boundaries. You will see that the Logical Volume size has expanded smoothly from **10.00 GiB** to **17.90 GiB** across both raw active underlying disks (`nvme1n1` and `nvme2n1`):

```bash
# Run this final step to expand your actual file system tracking layer to match the new size:
resize2fs /dev/rdn/rdn_adn
```

---

## 🚀 Advanced Production Steps (Day-2 Operations)

### Auto-Mount Volumes on System Boot
Manual mounts disappear if your AWS EC2 instance undergoes a reboot or crash. To protect your mounting persistence configuration, append both entries to your environment filesystem table:

```bash
echo "/dev/rdn/rdn_adn /mnt/rdn_lv_mont ext4 defaults,nofail 0 2" >> /etc/fstab
echo "/dev/nvme3n1 /mnt/rdn_disk_mount ext4 defaults,nofail 0 2" >> /etc/fstab
```
*(The `nofail` flag guarantees that your Linux instance continues its boot sequence normally even if an unmapped backing EBS drive fails to respond or attach).*

