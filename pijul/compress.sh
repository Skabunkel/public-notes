# Compress and compare sizes of dires, compressed with dict and without.

mkdir -p /tmp/c_nodict /tmp/c_dict
for f in /tmp/pchanges/*; do
  b=$(basename "$f")
  zstd -q19 "$f" -o "/tmp/c_nodict/$b.zst"
  zstd -q19 -D /tmp/changes.dict "$f" -o "/tmp/c_dict/$b.zst"
done
du --apparent-size -s --block-size=1 /tmp/c_nodict /tmp/c_dict
du -s --block-size=1 /tmp/c_nodict /tmp/c_dict
