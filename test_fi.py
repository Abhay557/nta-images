import subprocess, os, time, sys

REPO = r"F:\nta"

files = ['2/4128/100_20200627194150.jpg']
prog = subprocess.Popen(
    ["git", "-C", REPO, "fast-import"],
    stdin=subprocess.PIPE, stderr=subprocess.PIPE
)

def w(s):
    prog.stdin.write(s.encode() if isinstance(s, str) else s)

ts = int(time.time())
msg = "test import"
w("commit refs/heads/testimport\n")
w("mark :1\n")
w("author Abhay <abhaycormourya@gmail.com> %d +0000\n" % ts)
w("committer Abhay <abhaycormourya@gmail.com> %d +0000\n" % ts)
w("data %d\n" % len(msg))
w(msg + "\n")
w("from refs/heads/main\n")

for f in files:
    src = os.path.join(REPO, *f.split("/"))
    size = os.path.getsize(src)
    w("M 100644 inline %s\n" % f)
    w("data %d\n" % size)
    with open(src, "rb") as fh:
        while True:
            c = fh.read(65536)
            if not c:
                break
            w(c)
    w("\n")

w("\n")
w("done\n")
prog.stdin.close()
prog.wait()
err = prog.stderr.read().decode(errors="replace")
print("exit:", prog.returncode)
print("STDERR:\n" + err)
