#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""阶段 3 稳定性回归测试：覆盖阶段 2 所有改动分支。

用例全部为黑盒（完整脚本 + PATH 命令桩），断言只依赖可靠信号：
mntroot 调用序列、文件最终内容、msg.sh 的 KUAL_MSG_LOG。
所有 /usr/bin、/etc/hosts、GT_TMPD、reboot 均重定向到临时目录。

覆盖矩阵：
  正常路径  : clean_hosts 过滤 / OTA rename+restore 成功 / 谷歌 -d 删除
  边界值    : 空 hosts / 源缺失 / curl 全失败（无可用 IP）
  非法输入  : hosts 源不可读时绝不 mv 覆盖
  依赖失败  : mv 失败、cd 失败、GT_RW_HELD 异常退出恢复 ro
  重复执行  : clean_hosts 幂等 / OTA already-blocked / not-blocked 幂等
"""
import os
import sys
import tempfile
import subprocess
import shutil

HELPER = "/workspace/helper"
BIN = os.path.join(HELPER, "bin")
GT = os.path.join(BIN, "fix-google-translate", "fix_google_translate.sh")
RENAME = os.path.join(BIN, "block-ota", "rename.sh")
RESTORE = os.path.join(BIN, "block-ota", "restore.sh")

results = []


def check(name, cond, detail=""):
    results.append((name, bool(cond)))
    print("[%s] %-48s%s" % ("PASS" if cond else "FAIL", name,
                            ("  | " + detail) if detail else ""))


def mkstub(d, name, body):
    p = os.path.join(d, name)
    with open(p, "w") as f:
        f.write("#!/bin/sh\n" + body + "\n")
    os.chmod(p, 0o755)


def run(original, transform, extra_stubs=None, args=None):
    """把 transform 后的脚本副本写到原目录（.probe_ 前缀）。

    写到原目录而非 /tmp，是因为脚本引导头要靠 $0 的 dirname 向上找 common.sh；
    只有 common.sh 正确加载，msg.sh 才会写 KUAL_MSG_LOG，消息才可断言。
    返回 (CompletedProcess, mnt调用列表, 消息文本, 临时目录)。
    """
    td = tempfile.mkdtemp(prefix="kual_")
    stub = os.path.join(td, "stub")
    os.makedirs(stub)
    mntlog = os.path.join(td, "mnt.log")
    msglog = os.path.join(td, "msg.log")
    mkstub(stub, "mntroot", "printf '%s\\n' \"$*\" >> '" + mntlog + "'")
    for n, b in (extra_stubs or {}).items():
        mkstub(stub, n, b)
    probe = os.path.join(os.path.dirname(original), ".probe_" + os.path.basename(original))
    src = transform(open(original, encoding="utf-8").read(), td)
    with open(probe, "w", encoding="utf-8") as f:
        f.write(src)
    os.chmod(probe, 0o755)
    env = dict(os.environ)
    env["PATH"] = stub + os.pathsep + env.get("PATH", "")
    env["KUAL_HOME"] = HELPER
    env["KUAL_ACTION"] = "probe"
    env["KUAL_MSG_LOG"] = msglog
    r = subprocess.run(["/bin/sh", probe] + (args or []), capture_output=True, text=True, env=env)
    os.remove(probe)
    mnt = open(mntlog).read().strip().splitlines() if os.path.exists(mntlog) else []
    msg = open(msglog, encoding="utf-8", errors="replace").read() if os.path.exists(msglog) else ""
    return r, mnt, msg, td


# ===========================================================================
# 1) GT EXIT 清理：rw-held 恢复 ro / 无 rw 不误调用（白盒片段，已验证可靠）
# ===========================================================================
def test_gt_cleanup():
    lines = open(GT, encoding="utf-8").read().splitlines()
    s = next(i for i, l in enumerate(lines) if l.startswith("_gt_cleanup()"))
    e = next(i for i in range(s + 1, len(lines)) if lines[i].startswith("clean_hosts()"))
    head = "\n".join(lines[:s] + lines[s:e])
    head = head.replace('$(dirname -- "$0")', "'" + BIN + "'")
    for label, held, expect in (("rw-held", 1, True), ("no-rw", 0, False)):
        td = tempfile.mkdtemp(prefix="cln_" + label + "_")
        stub = os.path.join(td, "stub"); os.makedirs(stub)
        mntlog = os.path.join(td, "mnt.log")
        mkstub(stub, "mntroot", "printf '%s\\n' \"$*\" >> '" + mntlog + "'")
        ps = os.path.join(td, "p.sh")
        open(ps, "w").write(head + "\nGT_RW_HELD=" + str(held) + "\n_gt_cleanup\n")
        env = dict(os.environ); env["PATH"] = stub + ":" + env["PATH"]
        env["KUAL_HOME"] = HELPER; env["KUAL_ACTION"] = "probe"
        subprocess.run(["/bin/sh", ps], capture_output=True, text=True, env=env)
        log = open(mntlog).read() if os.path.exists(mntlog) else ""
        if expect:
            check("gt_cleanup: rw-held -> restore ro", ("ro" in log and "rw" not in log), repr(log.strip().splitlines()))
        else:
            check("gt_cleanup: no-rw -> no mnt call", (log.strip() == ""), repr(log.strip().splitlines()))
        shutil.rmtree(td, ignore_errors=True)


# ===========================================================================
# 2) clean_hosts：正常 / 空 / 源缺失 / mv 失败 / 幂等（白盒片段）
# ===========================================================================
def test_clean_hosts():
    lines = open(GT, encoding="utf-8").read().splitlines()
    s = next(i for i, l in enumerate(lines) if l.startswith("clean_hosts()"))
    e = next(i for i in range(s + 1, len(lines)) if lines[i].startswith("# -d：仅删除规则"))
    base = "\n".join(lines[:s] + lines[s:e]).replace('$(dirname -- "$0")', "'" + BIN + "'")

    def do(hosts, runs, stub_mv=False):
        td = tempfile.mkdtemp(prefix="ch_")
        stub = os.path.join(td, "stub"); os.makedirs(stub)
        mkstub(stub, "eips", "exit 0")
        if stub_mv:
            mkstub(stub, "mv", "exit 1")
        ps = os.path.join(td, "p.sh")
        open(ps, "w").write(base + "\nHOSTS_FILE='" + hosts + "'\n" + "clean_hosts\n" * runs
                            + "printf 'RC=%s\\n' \"$?\"\n")
        env = dict(os.environ); env["PATH"] = stub + ":" + env["PATH"]
        env["KUAL_HOME"] = HELPER; env["KUAL_ACTION"] = "probe"
        r = subprocess.run(["/bin/sh", ps], capture_output=True, text=True, env=env)
        return r

    # A 正常过滤
    td = tempfile.mkdtemp(prefix="cha_"); h = os.path.join(td, "hosts")
    open(h, "w").write("127.0.0.1 localhost\n142.250.4.90 translate.googleapis.com\n"
                       "# Fix Google Translate CN tested=8\n192.168.1.1 printer\n")
    r = do(h, 1); c = open(h).read()
    check("clean_hosts: normal filters marked lines",
          ("RC=0" in r.stdout and "localhost" in c and "printer" in c
           and "googleapis" not in c and "Fix Google" not in c), repr(c.strip().splitlines()))
    shutil.rmtree(td, ignore_errors=True)
    # B 源缺失
    td = tempfile.mkdtemp(prefix="chb_"); h = os.path.join(td, "missing")
    r = do(h, 1)
    check("clean_hosts: missing source -> RC=1 no clobber",
          ("RC=1" in r.stdout and not os.path.exists(h)), "exists=%s" % os.path.exists(h))
    shutil.rmtree(td, ignore_errors=True)
    # C 空文件
    td = tempfile.mkdtemp(prefix="chc_"); h = os.path.join(td, "empty"); open(h, "w").write("")
    r = do(h, 1)
    check("clean_hosts: empty file -> RC=0 stays empty", ("RC=0" in r.stdout and open(h).read() == ""))
    shutil.rmtree(td, ignore_errors=True)
    # D mv 失败
    td = tempfile.mkdtemp(prefix="chd_"); h = os.path.join(td, "hosts")
    open(h, "w").write("127.0.0.1 localhost\n142.250.4.90 translate.googleapis.com\n")
    r = do(h, 1, stub_mv=True); c = open(h).read()
    check("clean_hosts: mv fail -> RC=1 keeps original",
          ("RC=1" in r.stdout and "googleapis" in c), repr(c.strip().splitlines()))
    shutil.rmtree(td, ignore_errors=True)
    # E 幂等
    td = tempfile.mkdtemp(prefix="che_"); h = os.path.join(td, "hosts")
    open(h, "w").write("127.0.0.1 localhost\n142.250.4.90 translate.googleapis.com\n")
    r = do(h, 2)
    check("clean_hosts: idempotent (2x run)", ("RC=0" in r.stdout and open(h).read() == "127.0.0.1 localhost\n"))
    shutil.rmtree(td, ignore_errors=True)


# ===========================================================================
# 3) GT -d：正常删除 / 源缺失仍恢复 ro（黑盒完整脚本 + -d 参数）
# ===========================================================================
def test_gt_delete():
    def tr(src, td):
        h = os.path.join(td, "hosts")
        open(h, "w").write("127.0.0.1 localhost\n142.250.4.90 translate.googleapis.com\n")
        return src.replace("HOSTS_FILE=/etc/hosts", "HOSTS_FILE='" + h + "'")
    r, mnt, msg, td = run(GT, tr, args=["-d"])
    ok = ("rw" in mnt and "ro" in mnt and "googleapis" not in open(os.path.join(td, "hosts")).read()
          and "rule removed" in msg)
    check("gt -d: rw/ro paired + rule removed", ok,
          "mnt=%r msg_has=%s" % (mnt, "rule removed" in msg))
    shutil.rmtree(td, ignore_errors=True)

    def tr_missing(src, td):
        return src.replace("HOSTS_FILE=/etc/hosts", "HOSTS_FILE='" + os.path.join(td, "missing") + "'")
    r, mnt, msg, td = run(GT, tr_missing, args=["-d"])
    check("gt -d: missing source still restores ro",
          ("rw" in mnt and "ro" in mnt), "mnt=%r" % mnt)
    shutil.rmtree(td, ignore_errors=True)


# ===========================================================================
# 4) GT 主流程：curl 全失败 -> 可读失败消息 + 恢复 ro
# ===========================================================================
def test_gt_no_ip():
    def tr(src, td):
        src = src.replace("HOSTS_FILE=/etc/hosts", "HOSTS_FILE='" + os.path.join(td, "hosts") + "'")
        src = src.replace("GT_TMPD=/tmp/kual_gt_$$", "GT_TMPD='" + os.path.join(td, "tmpd") + "'")
        src = src.replace("MAX_TRIES=${KUAL_GT_MAX_TRIES:-0}", "MAX_TRIES=2")
        return src
    r, mnt, msg, td = run(GT, tr, extra_stubs={"curl": "printf '\\n000\\n'"})
    ok = ("rw" in mnt and "ro" in mnt and "No reachable IP" in msg)
    check("gt main: curl all fail -> fail msg + ro", ok,
          "mnt=%r fail_msg=%s" % (mnt, "No reachable IP" in msg))
    shutil.rmtree(td, ignore_errors=True)


# ===========================================================================
# 5) OTA rename/restore：成功 / 幂等 / mv 失败 / cd 失败
# ===========================================================================
def ota(original, kind, extra_stubs=None, cd_target=None):
    def tr(src, td):
        fb = os.path.join(td, "fakebin"); os.makedirs(fb)
        if kind in ("real", "rename_mv_fail", "rename_cd_fail"):
            open(os.path.join(fb, "otaupd"), "w").write("REAL")
            open(os.path.join(fb, "otav3"), "w").write("REAL")
        elif kind == "bck":  # backup present
            open(os.path.join(fb, "otaupd.bck"), "w").write("REAL")
            open(os.path.join(fb, "otav3.bck"), "w").write("REAL")
        # kind == "none": 什么都不建（用于 restore 幂等：无 .bck）
        src = src.replace("cd /usr/bin", "cd '" + (cd_target or fb) + "'")
        src = src.replace("/usr/bin/", fb + "/")
        src = src.replace("reboot", ":")
        src = src.replace("sleep 2", ":")
        return src
    stubs = dict(extra_stubs or {})
    return run(original, tr, extra_stubs=stubs)


def test_ota():
    # rename 成功
    r, mnt, msg, td = ota(RENAME, "real")
    check("rename: success rw/ro paired, no fail",
          ("rw" in mnt and "ro" in mnt and "Cannot back up" not in msg and "replaced" in msg),
          "mnt=%r" % mnt); shutil.rmtree(td, ignore_errors=True)
    # rename 幂等
    r, mnt, msg, td = ota(RENAME, "bck")
    check("rename: idempotent -> already blocked, ro",
          ("ro" in mnt and "already blocked" in msg and "Cannot back up" not in msg),
          "mnt=%r msg=%r" % (mnt, msg.strip()[:80])); shutil.rmtree(td, ignore_errors=True)
    # rename mv 失败
    r, mnt, msg, td = ota(RENAME, "rename_mv_fail", {"mv": "exit 1"})
    check("rename: mv fail -> ro + readable error",
          ("rw" in mnt and "ro" in mnt and "Cannot back up" in msg), "mnt=%r" % mnt)
    shutil.rmtree(td, ignore_errors=True)
    # rename cd 失败
    r, mnt, msg, td = ota(RENAME, "rename_cd_fail", cd_target="/nonexistent/kual/path")
    check("rename: cd fail -> ro + readable error",
          ("ro" in mnt and "Cannot access" in msg), "mnt=%r" % mnt); shutil.rmtree(td, ignore_errors=True)
    # restore 成功
    r, mnt, msg, td = ota(RESTORE, "bck")
    check("restore: success rw/ro paired, no fail",
          ("rw" in mnt and "ro" in mnt and "restored" in msg and "Cannot restore" not in msg),
          "mnt=%r" % mnt); shutil.rmtree(td, ignore_errors=True)
    # restore 幂等
    r, mnt, msg, td = ota(RESTORE, "none")
    check("restore: idempotent(no .bck) -> not blocked, ro",
          ("ro" in mnt and "not blocked" in msg and "Cannot restore" not in msg),
          "mnt=%r msg=%r" % (mnt, msg.strip()[:80])); shutil.rmtree(td, ignore_errors=True)
    # restore mv 失败
    r, mnt, msg, td = ota(RESTORE, "bck", {"mv": "exit 1"})
    check("restore: mv fail -> ro + readable error",
          ("rw" in mnt and "ro" in mnt and "Cannot restore" in msg), "mnt=%r" % mnt)
    shutil.rmtree(td, ignore_errors=True)


test_gt_cleanup()
test_clean_hosts()
test_gt_delete()
test_gt_no_ip()
test_ota()

passed = sum(1 for _, ok in results if ok)
print("\nSUMMARY: %d/%d passed" % (passed, len(results)))
sys.exit(0 if passed == len(results) else 1)
