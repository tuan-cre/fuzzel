#!/usr/bin/env python3
import sys
import onnxruntime as ort
from PIL import Image
from rembg import new_session, remove

if len(sys.argv) != 4:
    print(f"Usage: {sys.argv[0]} <model> <input> <output>", file=sys.stderr)
    sys.exit(1)

model, inp, out = sys.argv[1], sys.argv[2], sys.argv[3]

sess_opts = ort.SessionOptions()
# Disable memory pattern for dynamic shapes (fixes BFCArena 822M on birefnet)
try:
    sess_opts.add_session_config_entry("memory.enable_memory_pattern", "0")
except Exception:
    pass
# Bypass arena for initializers (fixes BFCArena growth on 928M weights)
try:
    sess_opts.add_session_config_entry("kOrtSessionOptionsUseDeviceAllocatorForInitializers", "1")
except Exception:
    pass
# Alternative: disable GPU arena entirely (fallback, still GPU)
try:
    sess_opts.add_session_config_entry("gpu_mem_limit", "4294967296")  # 4GB limit
except Exception:
    pass

session = new_session(model, sess_opts=sess_opts)
img = Image.open(inp)
# remove will use provided session
result = remove(img, session=session)
result.save(out)
print(f"saved {out} with {model} (arena disabled, GPU)")
