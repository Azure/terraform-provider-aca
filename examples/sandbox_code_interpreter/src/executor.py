import asyncio
import os
import selectors
import signal
import subprocess
import sys
import tempfile
import time
from collections.abc import Mapping
from pathlib import Path
from typing import Any

MAX_CODE_BYTES = 100_000
MAX_OUTPUT_BYTES = 64_000
MAX_TIMEOUT_SECONDS = 60
EXECUTOR_UID = 10001
EXECUTOR_GID = 10001

_INHERITED_ENVIRONMENT = {
    "LANG",
    "LC_ALL",
    "PATH",
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "NO_PROXY",
    "REQUESTS_CA_BUNDLE",
    "SSL_CERT_FILE",
}

_RESOURCE_LIMIT_RUNNER = """\
import ctypes
import ctypes.util
import errno
import resource
import runpy
import sys


def install_seccomp_filter():
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(38, 1, 0, 0, 0) != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, "prctl(PR_SET_NO_NEW_PRIVS) failed")

    library_path = ctypes.util.find_library("seccomp")
    if not library_path:
        raise RuntimeError("libseccomp is required for process containment")

    seccomp = ctypes.CDLL(library_path)
    seccomp.seccomp_init.argtypes = [ctypes.c_uint32]
    seccomp.seccomp_init.restype = ctypes.c_void_p
    seccomp.seccomp_syscall_resolve_name.argtypes = [ctypes.c_char_p]
    seccomp.seccomp_syscall_resolve_name.restype = ctypes.c_int
    seccomp.seccomp_rule_add.argtypes = [
        ctypes.c_void_p,
        ctypes.c_uint32,
        ctypes.c_int,
        ctypes.c_uint,
    ]
    seccomp.seccomp_rule_add.restype = ctypes.c_int
    seccomp.seccomp_load.argtypes = [ctypes.c_void_p]
    seccomp.seccomp_load.restype = ctypes.c_int
    seccomp.seccomp_release.argtypes = [ctypes.c_void_p]

    context = seccomp.seccomp_init(0x7FFF0000)
    if not context:
        raise RuntimeError("seccomp_init failed")

    try:
        deny_action = 0x00050000 | errno.EPERM
        for syscall_name in (b"setsid", b"setpgid", b"unshare", b"setns"):
            syscall_number = seccomp.seccomp_syscall_resolve_name(syscall_name)
            if syscall_number < 0:
                continue
            result = seccomp.seccomp_rule_add(
                context,
                deny_action,
                syscall_number,
                0,
            )
            if result != 0:
                raise OSError(-result, f"seccomp rule failed for {syscall_name!r}")

        result = seccomp.seccomp_load(context)
        if result != 0:
            raise OSError(-result, "seccomp_load failed")
    finally:
        seccomp.seccomp_release(context)


timeout_seconds = int(sys.argv[1])
script_path = sys.argv[2]
memory_bytes = 2 * 1024 * 1024 * 1024

resource.setrlimit(resource.RLIMIT_AS, (memory_bytes, memory_bytes))
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
resource.setrlimit(resource.RLIMIT_CPU, (timeout_seconds + 1, timeout_seconds + 1))
resource.setrlimit(resource.RLIMIT_FSIZE, (50 * 1024 * 1024, 50 * 1024 * 1024))
resource.setrlimit(resource.RLIMIT_NOFILE, (128, 128))
if hasattr(resource, "RLIMIT_NPROC"):
    resource.setrlimit(resource.RLIMIT_NPROC, (64, 64))

install_seccomp_filter()
sys.argv = [script_path]
runpy.run_path(script_path, run_name="__main__")
"""


def _execution_environment(
    working_directory: Path,
    source: Mapping[str, str] | None = None,
) -> dict[str, str]:
    source = source or os.environ
    environment = {
        key: value for key, value in source.items() if key in _INHERITED_ENVIRONMENT
    }
    environment.update(
        {
            "HOME": str(working_directory),
            "TMPDIR": str(working_directory),
            "PYTHONUNBUFFERED": "1",
            "PYTHONDONTWRITEBYTECODE": "1",
        }
    )
    return environment


def _terminate_process_group(process: subprocess.Popen[bytes]) -> None:
    if os.name == "posix":
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    elif process.poll() is None:
        process.kill()


def _communicate_bounded(
    process: subprocess.Popen[bytes],
    timeout_seconds: int,
) -> tuple[str, str, bool, bool]:
    if process.stdout is None or process.stderr is None:
        raise RuntimeError("subprocess pipes were not configured")

    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ, "stdout")
    selector.register(process.stderr, selectors.EVENT_READ, "stderr")
    buffers = {"stdout": bytearray(), "stderr": bytearray()}
    truncated_streams: set[str] = set()
    deadline = time.monotonic() + timeout_seconds
    timed_out = False
    terminated = False

    try:
        while process.poll() is None or selector.get_map():
            remaining = deadline - time.monotonic()
            if remaining <= 0 and not terminated:
                timed_out = True
                terminated = True
                _terminate_process_group(process)
            elif process.poll() is not None and selector.get_map() and not terminated:
                terminated = True
                _terminate_process_group(process)

            if selector.get_map():
                events = selector.select(timeout=max(0.0, min(0.1, remaining)))
            else:
                time.sleep(max(0.0, min(0.05, remaining)))
                events = []

            for key, _ in events:
                chunk = os.read(key.fileobj.fileno(), 8192)
                if not chunk:
                    selector.unregister(key.fileobj)
                    continue

                stream_name = str(key.data)
                capacity = MAX_OUTPUT_BYTES - len(buffers[stream_name])
                if capacity > 0:
                    buffers[stream_name].extend(chunk[:capacity])
                if len(chunk) > capacity:
                    truncated_streams.add(stream_name)
                    if not terminated:
                        terminated = True
                        _terminate_process_group(process)
    finally:
        selector.close()

    process.wait()

    def decode(stream_name: str) -> str:
        value = buffers[stream_name].decode("utf-8", errors="replace")
        if stream_name in truncated_streams:
            return f"{value}\n...[output truncated]"
        return value

    return (
        decode("stdout"),
        decode("stderr"),
        timed_out,
        bool(truncated_streams),
    )


def _execute(code: str, timeout_seconds: int) -> dict[str, Any]:
    if not code.strip():
        raise ValueError("code must not be empty")
    if len(code.encode("utf-8")) > MAX_CODE_BYTES:
        raise ValueError(f"code must be at most {MAX_CODE_BYTES} bytes")
    if not 1 <= timeout_seconds <= MAX_TIMEOUT_SECONDS:
        raise ValueError(
            f"timeout_seconds must be between 1 and {MAX_TIMEOUT_SECONDS}"
        )

    with tempfile.TemporaryDirectory(prefix="python-exec-") as temp_directory:
        execution_root = Path(temp_directory)
        workdir = execution_root / "workspace"
        script_path = execution_root / "main.py"
        runner_path = execution_root / "runner.py"
        workdir.mkdir()
        script_path.write_text(code, encoding="utf-8")
        runner_path.write_text(_RESOURCE_LIMIT_RUNNER, encoding="utf-8")
        if os.name == "posix":
            os.chmod(execution_root, 0o755)
            os.chmod(script_path, 0o444)
            os.chmod(runner_path, 0o444)
            os.chown(workdir, EXECUTOR_UID, EXECUTOR_GID)
            os.chmod(workdir, 0o700)

        process_args: dict[str, Any] = {
            "args": [
                sys.executable,
                "-I",
                "-u",
                str(runner_path),
                str(timeout_seconds),
                str(script_path),
            ],
            "cwd": workdir,
            "env": _execution_environment(workdir),
            "stdout": subprocess.PIPE,
            "stderr": subprocess.PIPE,
            "start_new_session": True,
        }
        if os.name == "posix":
            process_args.update(
                {
                    "user": EXECUTOR_UID,
                    "group": EXECUTOR_GID,
                    "extra_groups": (),
                    "umask": 0o077,
                }
            )

        process = subprocess.Popen(**process_args)
        stdout, stderr, timed_out, output_truncated = _communicate_bounded(
            process,
            timeout_seconds,
        )
        return {
            "exit_code": process.returncode,
            "timed_out": timed_out,
            "stdout": stdout,
            "stderr": stderr,
            "output_truncated": output_truncated,
        }


async def execute_python(code: str, timeout_seconds: int = 30) -> dict[str, Any]:
    return await asyncio.to_thread(_execute, code, timeout_seconds)
