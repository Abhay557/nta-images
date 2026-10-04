import subprocess, sys, os, time, io

REPO = r"F:\nta"
BRANCH = "refs/heads/imptmp"
BASE = "refs/heads/main"
FOLDER = "2"
HELPERS = {"batch_2.ps1", "batch_2.log"}

# Gather untracked files under folder 2 only (exclude helper files at repo root).
raw = subprocess.run(
    ["git", "-C", REPO, "ls-files", "--others", "--exclude-standard"],
    capture_output=True, text=True
).stdout.splitlines()

files = []
for p in raw:
    if p.startswith(FOLDER + "/"):
        top = p.split("/")[1]
        if not any(p == h for h in HELPERS):
            files.append(p)
        # skip non-subdir files at folder root too (rare)
# keep only paths that live under a subdir of folder 2
files = [f for f in files if "/" in f[len(FOLDER)+1:]]

print(f"files to import: {len(files)}", flush=True)

BATCH = 3000
git = subprocess.Popen(
    ["git", "-C", REPO, "fast-import", "--quiet"],
    stdin=subprocess.PIPE
)
stdin = git.stdin
buf = io.BufferedWriter(stdin, buffer_size=1024*1024)

def w(s):
    buf.write(s.encode("utf-8") if isinstance(s, str) else s)

def data_block(path, total):
    # stream file bytes in chunks to avoid huge memory
    with open(os.path.join(REPO, *path.replace("/", os.sep).split("/")), "rb") as fh:
        size = os.path.getsize(fh.name)
        # write data header; need len BEFORE content for inline -> use data <len>
        w(("data %d\n" % size))
        while True:
            chunk = fh.read(1024*1024)
            if not chunk:
                break
            w(chunk)
        w(b"\n")

commit_msg = "Add {folder} (part {n})"

first = True
n = 0
idx = 0
while idx < len(files):
    n += 1
    w("commit %s\n" % BRANCH)
    w("mark :%d\n" % n)
    ts = int(time.time())
    w("author Abhay <%s> %d +0000\n" % ("abhaycormourya@gmail.com", ts))
    w("committer Abhay <%s> %d +0000\n" % ("abhaycormourya@gmail.com", ts))
    msg = commit_msg.format(folder=FOLDER, n=n)
    w("data %d\n" % len(msg))
    w(msg + "\n")
    if first:
        w("from %s\n" % BASE)
        first = False
    slice_files = files[idx:idx+BATCH]
    for f in slice_files:
        w("M 100644 inline ")
        w(f)
        w("\n")
        data_block(f, 0)
    w("\n")  # finalize commit
    idx += BATCH
    print(f"queued commit {n} ({len(slice_files)} files)", flush=True)

w("done\n")
buf.flush()
stdin.flush()
buf.close()
try:
    stdin.close()
except Exception:
    pass
rc = git.wait()
print("fast-import exit code:", rc, flush=True)
