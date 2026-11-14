"""Verify every exported PCK entry and its compiled startup configuration."""
import hashlib
import struct
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = path.read_bytes()
assert data[:4] == b"GDPC" and struct.unpack_from("<I", data, 4)[0] == 4, "Unexpected PCK format"
base, pos = struct.unpack_from("<QQ", data, 24)
count = struct.unpack_from("<I", data, pos)[0]
pos += 4
entries = {}
for _ in range(count):
    size = struct.unpack_from("<I", data, pos)[0]
    pos += 4
    name = data[pos:pos + size].rstrip(b"\0").decode("utf-8")
    pos += size
    offset, length = struct.unpack_from("<QQ", data, pos)
    pos += 16
    digest = data[pos:pos + 16]
    pos += 20  # MD5 plus entry flags.
    payload = data[base + offset:base + offset + length]
    assert len(payload) == length, f"Truncated resource: {name}"
    assert hashlib.md5(payload).digest() == digest, f"Checksum mismatch: {name}"
    entries[name] = payload
project = entries.get("project.binary", b"")
assert project[:4] == b"ECFG" and len(project) > 100, "Exported project settings are missing or empty"
assert b"prologue_demo" in project and b"PrologueDemo.tscn" in project, "Standalone startup feature is missing"
if b"prologue_validation" not in project:
    assert not any("prologue_package_validation" in name for name in entries), "Private QA was included in the playable export"
assert not any(name.startswith((".runtime/", "tests/", "build/")) for name in entries), "Development output was included"
print(f"PCK verified: {count} checksummed resources, project.binary={len(project)} bytes, archive={len(data)} bytes")
