# pythonocc-wheels

Build scripts for [pythonocc-core](https://github.com/tpaviot/pythonocc-core) wheels on Linux and macOS (Apple Silicon).

| Component | Version |
|---|---|
| pythonocc-core | 7.9.3 |
| OCCT | 7.9.3 |
| SWIG | 4.2.1 |
| Python | 3.11 |

| Platform | Result | Portability |
|---|---|---|
| Linux x86_64 | `manylinux_2_28_x86_64` wheel | Any Linux compatible with manylinux_2_28 |
| macOS arm64 | `macosx_<version>_arm64` wheel | Tagged for the macOS it was built on; not intended for older versions |

## Linux

Run from the repository root on an x86_64 host. On an Apple Silicon Mac the image would run under emulation.

```bash
docker build -f linux/Dockerfile -t pythonocc-wheel-builder .

docker create --name wheel-extract pythonocc-wheel-builder:latest
docker cp wheel-extract:/dist ./dist
docker rm wheel-extract
```

## macOS

Requires Xcode, [Homebrew](https://brew.sh) and [uv](https://docs.astral.sh/uv/).

```bash
brew install cmake ninja pcre2 freetype rapidjson

uv venv --python 3.11 .venv
uv pip install --python .venv/bin/python numpy setuptools wheel delocate

mkdir -p build
macos/build.sh 2>&1 | tee build/build.log
```

The wheel is written to `dist/`. All intermediate files stay in `build/`, and finished steps are skipped on a repeated run. To start from scratch, delete `build/`.

## Testing

`tests/check_wheel.sh` installs a wheel into a clean virtual environment and runs `tests/smoke_test.py`: it builds a box, checks its volume and faces, meshes it and writes and reads it back as STEP. On macOS it also checks that the wheel does not link to libraries outside itself.

```bash
tests/check_wheel.sh dist/<wheel>.whl
```

## Using the wheel

```bash
uv pip install dist/<wheel>.whl numpy
```

```python
from OCC.Core.BRepPrimAPI import BRepPrimAPI_MakeBox

shape = BRepPrimAPI_MakeBox(10, 20, 30).Shape()
```
