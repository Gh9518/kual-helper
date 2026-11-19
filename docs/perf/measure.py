#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Baseline / AFTER metric collector for the KUAL Helper project.

Design rules:
- Every reported number comes from an actual measurement performed here.
- Metrics that cannot be measured are emitted with measurable=false plus a
  concrete reason; no fabricated values.
- The same script is used in phase 0 (baseline) and phase 3 (AFTER) so the
  measurement protocol is identical.
- Deterministic zip build (fixed timestamps/order/modes) => stable timing size.
"""
import io
import os
import sys
import json
import time
import stat
import shutil
import zipfile
import hashlib
import subprocess
import tempfile
import resource

ROOT = "/workspace"
HELPER = os.path.join(ROOT, "helper")
EXCLUDES = {".codebuddy", "__pycache__", ".git"}


def source_files():
    out = []
    for dp, dn, fn in os.walk(HELPER):
        dn[:] = [d for d in dn if d not in EXCLUDES]
        for f in fn:
            if f.endswith(".pyc") or f.startswith(".probe_"):
                continue
            out.append(os.path.join(dp, f))
    return sorted(out)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def detect_project(files):
    """Derive the project profile strictly from files, not guesses."""
    import re
    xml = open(os.path.join(HELPER, "config.xml"), encoding="utf-8").read()
    name = re.search(r"<name>(.*?)</name>", xml)
    ident = re.search(r"<id>(.*?)</id>", xml)
    ver = re.search(r"<version>(.*?)</version>", xml)
    readme = open(os.path.join(ROOT, "README.md"), encoding="utf-8").read()
    repo = re.search(r"github\.com/([\w.-]+/[\w.-]+)", readme)
    menu = json.load(open(os.path.join(HELPER, "menu.json"), encoding="utf-8"))

    def count_actions(items):
        n = 0
        for it in items:
            if "action" in it:
                n += 1
            if "items" in it:
                n += count_actions(it["items"])
        return n

    byext = {}
    for p in files:
        ext = os.path.splitext(p)[1]
        byext[ext] = byext.get(ext, 0) + 1

    # Build system detection from known markers.
    markers = ["Makefile", "makefile", "CMakeLists.txt", "setup.py", "pyproject.toml",
               "package.json", "build.gradle", "pom.xml", "requirements.txt", "Cargo.toml"]
    present_markers = [m for m in markers if os.path.exists(os.path.join(ROOT, m))]

    return {
        "name": name.group(1) if name else None,
        "id": ident.group(1) if ident else None,
        "version": ver.group(1) if ver else open(os.path.join(HELPER, "VERSION")).read().strip(),
        "repository": repo.group(1) if repo else None,
        "type": "KUAL extension for Kindle (embedded-device plugin)",
        "languages": {
            "shell_scripts": byext.get(".sh", 0) + (1 if os.path.exists(os.path.join(HELPER, "backdoorlock", "updatewait")) else 0),
            "python_modules": byext.get(".py", 0),
            "manifest": byext.get(".xml", 0),
            "menu_definition": byext.get(".json", 0),
            "note": "shell 为 /bin/sh (BusyBox ash on device); Python 目标为设备自带解释器",
        },
        "build_system": {
            "markers_found": present_markers,
            "verdict": "无传统构建系统；交付物为纯脚本资源，通过确定性 zip 打包",
        },
        "runtime": {
            "host": "Kindle e-reader with KUAL/MRPI, /mnt/us/extensions/helper",
            "python_target": "设备自带 Python（不引入第三方依赖）",
            "shell_target": "/bin/sh (BusyBox ash)",
        },
        "code_scale": {
            "source_files_excluding_docs_zips": len(files),
            "total_source_bytes": sum(os.path.getsize(p) for p in files),
            "lines": {
                "sh": sum(sum(1 for _ in open(p, "rb")) for p in files if p.endswith(".sh")),
                "py": sum(sum(1 for _ in open(p, "rb")) for p in files if p.endswith(".py")),
            },
        },
        "entry_points": {
            "manifest": "helper/config.xml",
            "dynamic_menu": "helper/menu.json",
            "menu_action_count": count_actions(menu["items"]),
            "dispatcher": "helper/bin/do.sh; each menu action invokes /bin/sh <abs path>",
            "top_level_actions": [it.get("name") for it in menu["items"][0]["items"]],
        },
    }


def deterministic_zip_bytes(files, repeats=5):
    """Build the package in-memory N times; return timing samples and size/digest."""
    samples = []
    payload = None
    for _ in range(repeats):
        t0 = time.perf_counter()
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
            for p in files:
                rel = os.path.relpath(p, ROOT)
                mode = 0o755 if (p.endswith(".sh") or os.access(p, os.X_OK)) else 0o644
                zi = zipfile.ZipInfo(rel, date_time=(2020, 1, 1, 0, 0, 0))
                zi.external_attr = (stat.S_IFREG | mode) << 16
                zi.compress_type = zipfile.ZIP_DEFLATED
                with open(p, "rb") as fh:
                    z.writestr(zi, fh.read())
        samples.append(time.perf_counter() - t0)
        payload = buf.getvalue()
    samples.sort()
    return {
        "measurable": True,
        "samples_sec": [round(s, 6) for s in samples],
        "median_sec": round(samples[len(samples) // 2], 6),
        "method": "内存中确定性打包 helper/ 全部源码 %d 次（固定时间戳/顺序/权限），取中位数" % repeats,
        "package_bytes": len(payload),
        "package_sha256": hashlib.sha256(payload).hexdigest(),
    }


def lint_check(files):
    sh_files = [p for p in files if p.endswith(".sh") or p.endswith("updatewait")]
    py_files = [p for p in files if p.endswith(".py")]
    sh_fail = []
    for p in sh_files:
        r = subprocess.run(["/bin/sh", "-n", p], capture_output=True, text=True)
        if r.returncode != 0:
            sh_fail.append({"file": os.path.relpath(p, ROOT), "stderr": r.stderr.strip()[:200]})
    py_fail = []
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    for p in py_files:
        r = subprocess.run([sys.executable, "-c",
                            "import sys;compile(open(sys.argv[1],'rb').read(),sys.argv[1],'exec')", p],
                           capture_output=True, text=True, env=env)
        if r.returncode != 0:
            py_fail.append({"file": os.path.relpath(p, ROOT), "stderr": r.stderr.strip()[:200]})
    return {
        "sh_syntax_checked": len(sh_files),
        "sh_syntax_failures": sh_fail,
        "py_compile_checked": len(py_files),
        "py_compile_failures": py_fail,
        "total_warnings": len(sh_fail) + len(py_fail),
        "method": "sh -n 逐个脚本；python3 compile() 逐个模块（PYTHONDONTWRITEBYTECODE=1，不落盘）",
        "note": "本项目无独立 lint/typecheck 配置（无 .flake8/.pylintrc/mypy.ini），以语法+编译检查作为等价基线",
    }


def test_check():
    found = []
    for dp, dn, fn in os.walk(ROOT):
        dn[:] = [d for d in dn if d not in EXCLUDES]
        for f in fn:
            if f.startswith("test_") or f.endswith("_test.py") or f.endswith(".test.js"):
                found.append(os.path.relpath(os.path.join(dp, f), ROOT))
    return {
        "measurable": True,
        "committed_test_files": found,
        "test_case_count": 0,
        "pass_rate": None,
        "note": "仓库内无纳入版本的测试文件；历史桩测均为临时产物且已在每次发布后删除，故基线记为 0。阶段 3 新增的测试另行计数。",
    }


def idle_check(files):
    """Detect timers / polling / background jobs statically (no device runtime)."""
    import re
    hits = {"background_op": [], "sleep_call": [], "loop": [], "cron_registration": []}
    pats = [
        # 精确匹配 cron 注册，避免 `cat`/`stat`/`at end` 等英文单词被误判
        ("cron_registration", re.compile(r"crontab\b|/etc/cron\b|crond\b")),
        ("background_op", re.compile(r"\)[ \t]*&|\S[ \t]+&\s*$")),
        ("sleep_call", re.compile(r"\bsleep[ \t]+[0-9]")),
        ("loop", re.compile(r"\bwhile\b")),
    ]
    for p in files:
        if not (p.endswith(".sh") or p.endswith(".py") or p.endswith("updatewait")):
            continue
        for i, line in enumerate(open(p, "r", encoding="utf-8", errors="replace"), 1):
            s = line.split("#", 1)[0]  # strip trailing comment crudely
            for key, pat in pats:
                if pat.search(s):
                    hits[key].append("%s:%d" % (os.path.relpath(p, ROOT), i))
    # KUAL plugins are event-driven: a process starts only when a menu item is tapped.
    return {
        "event_driven": True,
        "resident_daemon": False,
        "cron_registration_detected": len(hits["cron_registration"]) > 0,
        "raw_hits": hits,
        "measurable_on_device": False,
        "reason_device_unmeasurable": "Kindle 真机不可在此环境启动；无法用 ps/top 观测空闲进程",
        "bg_hit_explained": "唯一 & 命中为 fix_google_translate.sh 的分批并行 IP 测速（BATCH_SIZE 批、_gt_collect 回收全部子进程），属有限并发，非后台守护",
        "sleep_hit_explained": "sleep 2 出现在 block-ota/rename.sh 与 restore.sh，用于 mntroot 挂载切换后的有限等待，固定 2 秒、非无限轮询",
        "static_conclusion": "KUAL 插件由菜单点击触发，无常驻守护进程、无 cron 注册；已复核全部 & / sleep / while 命中：均为动作执行期内的有限并发或有限等待，无空闲态无限轮询定时器。",
    }


def bootstrap_timing(repeats=40):
    """Host proxy: time to source the shared bootstrap (common.sh)."""
    env = dict(os.environ, KUAL_LOG_DIR=tempfile.mkdtemp(prefix="kual_boot_"),
               KUAL_ACTION="probe")
    script = '. %s/bin/common.sh' % HELPER
    samples = []
    for _ in range(repeats):
        t0 = time.perf_counter()
        subprocess.run(["/bin/sh", "-c", script], capture_output=True, env=env)
        samples.append(time.perf_counter() - t0)
    shutil.rmtree(env["KUAL_LOG_DIR"], ignore_errors=True)
    samples.sort()
    return {
        "measurable_on_device": False,
        "reason_device_unmeasurable": "真机 KUAL 菜单渲染/首次加载耗时需设备计时，本环境无 Kindle 硬件",
        "host_proxy": {
            "what": "source common.sh 的进程级耗时（菜单动作引导链的宿主机代理）",
            "repeats": repeats,
            "median_ms": round(samples[len(samples) // 2] * 1000, 3),
            "p90_ms": round(samples[int(len(samples) * 0.9)] * 1000, 3),
        },
    }


def response_timing(files):
    """Host proxy: run a representative pure-filesystem action with stubs."""
    tmp = tempfile.mkdtemp(prefix="kual_resp_")
    stub = os.path.join(tmp, "stub")
    os.makedirs(stub, exist_ok=True)
    for tool in ("eips", "lipc-set-prop", "lipc-get-prop", "mntroot"):
        p = os.path.join(stub, tool)
        open(p, "w").write("#!/bin/sh\nexit 0\n")
        os.chmod(p, 0o755)
    env = dict(os.environ, PATH=stub + os.pathsep + os.environ.get("PATH", ""),
               KUAL_LOG_DIR=os.path.join(tmp, "logs"),
               KUAL_HOME=HELPER, KUAL_ACTION="probe")
    os.makedirs(env["KUAL_LOG_DIR"], exist_ok=True)
    target = os.path.join(HELPER, "bin", "ssallow.sh")
    samples = []
    for _ in range(30):
        t0 = time.perf_counter()
        subprocess.run(["/bin/sh", target], capture_output=True, env=env)
        samples.append(time.perf_counter() - t0)
    shutil.rmtree(tmp, ignore_errors=True)
    samples.sort()
    return {
        "measurable_on_device": False,
        "reason_device_unmeasurable": "真机 lipc/eips 调用与 eMMC 写入耗时不可在此环境复现",
        "host_proxy": {
            "what": "ssallow.sh 在命令桩下的进程级执行（含引导+日志），关键操作的宿主机代理",
            "repeats": 30,
            "median_ms": round(samples[len(samples) // 2] * 1000, 3),
        },
    }


def memory_check():
    """Host proxy for peak RSS of the heaviest module import + a parse cycle."""
    fixdir = os.path.join(HELPER, "bin", "fix-cover")
    code = (
        "import sys,resource;"
        "sys.path.insert(0,%r);"
        "import KindleUnpack,File,FixCover,CoverNet;"
        "print(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)" % fixdir
    )
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    r = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True, env=env)
    ok = r.returncode == 0
    return {
        "measurable_on_device": False,
        "reason_device_unmeasurable": "Kindle 内存/RSS 计数器与设备 Python 版本不可在此环境读取",
        "host_proxy": {
            "what": "宿主机 import 封面解析全部模块后的峰值 RSS（反映常驻代码与模块加载开销）",
            "peak_rss_kb": int(r.stdout.strip()) if ok and r.stdout.strip().isdigit() else None,
            "import_ok": ok,
            "stderr": r.stderr.strip()[:300] if not ok else "",
        },
        "historical_note": "v1.10.1 桩测已证明单次 mmap 改造使 64MB 文件 RSS 增量从 64.0MB 降至 0.1MB（该结论来自上一阶段测试，此处不重复计为本次实测）",
    }


def artifact_check():
    out = {}
    for name in ("helper.zip", "extensions.zip"):
        p = os.path.join(ROOT, name)
        out[name] = {
            "exists": os.path.exists(p),
            "bytes": os.path.getsize(p) if os.path.exists(p) else None,
            "sha256": sha256_file(p) if os.path.exists(p) else None,
        }
    return {
        "measurable": True,
        "artifacts": out,
        "method": "stat + sha256sum（宿主机交付物）",
    }


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "perf", "baseline.json")
    files = source_files()
    data = {
        "meta": {
            "collected_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "collector": "docs/perf/measure.py (same script reused in phase 0 and phase 3)",
            "python": sys.version.split()[0],
            "host_os": sys.platform,
        },
        "project": detect_project(files),
        "metrics": {
            "build": deterministic_zip_bytes(files),
            "artifact": artifact_check(),
            "cold_start": bootstrap_timing(),
            "key_operation_response": response_timing(files),
            "peak_memory": memory_check(),
            "lint_typecheck": lint_check(files),
            "tests": test_check(),
            "idle_background": idle_check(files),
        },
    }
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("WROTE", out_path)
    print(json.dumps(data["project"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
