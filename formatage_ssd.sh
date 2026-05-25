#!/bin/bash

# === CONFIGURATION ===
DISK="/dev/sdb"         # ⚠️ adapte si ton disque change
LABEL="SSD_SANOU"
MOUNTPOINT="/mnt/$LABEL"

# === SÉCURITÉ : DEMANDE CONFIRMATION ===
echo "⚠️  ATTENTION : CE SCRIPT VA EFFACER TOUT LE CONTENU DE $DISK"
read -rp "Es-tu sûr de vouloir continuer ? (oui/non) : " confirm
if [[ "$confirm" != "oui" ]]; then
    echo "❌ Opération annulée."
    exit 1
fi

# === DÉMONTAGE SI NÉCESSAIRE ===
echo "🔧 Démontage de toutes les partitions de $DISK..."
for part in $(lsblk -ln -o NAME "$DISK" | tail -n +2); do
    sudo umount "/dev/$part" 2>/dev/null || true
done

# === CRÉATION DE LA TABLE DE PARTITION GPT ===
echo "📦 Création de la table de partition GPT..."
sudo parted "$DISK" --script mklabel gpt

# === CRÉATION D’UNE PARTITION PRINCIPALE EXT4 ===
echo "🧱 Création d'une partition EXT4..."
sudo parted "$DISK" --script mkpart primary ext4 1MiB 100%

# === ATTENTE QUE /dev/sdb1 APPARAISSE ===
echo "⏳ Attente que la partition soit disponible..."
PART="${DISK}1"
for i in {1..5}; do
    [ -b "$PART" ] && break
    sleep 1
done

# === FORMATAGE EN EXT4 AVEC ÉTIQUETTE ===
echo "🧼 Formatage en ext4 avec étiquette '$LABEL'..."
sudo mkfs.ext4 -F -L "$LABEL" "$PART"

# === CRÉATION DU POINT DE MONTAGE ===
echo "📁 Montage temporaire dans $MOUNTPOINT..."
sudo mkdir -p "$MOUNTPOINT"
sudo mount "$PART" "$MOUNTPOINT"
sudo chown -R ${USER}:${USER} /mnt/SSD_SANOU

# === AFFICHAGE DU RÉSULTAT ===
echo "✅ Disque formaté et monté temporairement à : $MOUNTPOINT"
lsblk -f | grep "$PART"

