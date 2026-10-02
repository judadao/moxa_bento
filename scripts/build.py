"""Export both desktop binaries and assemble Python launchers beside them."""
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
godot = shutil.which("godot") or shutil.which("godot4")
if not godot:
    raise SystemExit("Install Godot 4.4+ and matching export templates first.")
for platform, preset in (("linux", "Linux"), ("windows", "Windows")):
    destination = root / "build" / platform
    (destination / "bin").mkdir(parents=True, exist_ok=True)
    (root / "build" / ".gdignore").touch()
    subprocess.run([godot, "--headless", "--path", str(root), "--export-release", preset], check=True)
    for name in ("run.py", "requirements.txt", "README.md", f"setup-{platform}.{'bat' if platform == 'windows' else 'sh'}", f"start-{platform}.{'bat' if platform == 'windows' else 'sh'}"):
        shutil.copy2(root / name, destination / name)
    shutil.copytree(root / "companion", destination / "companion", dirs_exist_ok=True, ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copytree(root / "assets/fonts", destination / "licenses/fonts", dirs_exist_ok=True, ignore=shutil.ignore_patterns("*.import"))
    shutil.copytree(root / "docs", destination / "docs", dirs_exist_ok=True)
print("Built build/linux and build/windows. Python + Playwright setup is still required for real orders.")
