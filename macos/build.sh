#!/usr/bin/env bash
set -euo pipefail

SWIG_VERSION=4.2.1
OCCT_VERSION=7_9_3
PYTHONOCC_VERSION=7.9.3

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
PREFIX="$BUILD/occt793"
SRC="$BUILD/pythonocc-core"
PYTHON="$ROOT/.venv/bin/python"
SWIG="$BUILD/swig/bin/swig"

mkdir -p "$BUILD"

# SWIG
if [ ! -x "$SWIG" ]; then
  curl -L -o "$BUILD/swig.tar.gz" \
    "https://prdownloads.sourceforge.net/swig/swig-${SWIG_VERSION}.tar.gz"
  tar -xzf "$BUILD/swig.tar.gz" -C "$BUILD"
  (
    cd "$BUILD/swig-$SWIG_VERSION"
    ./configure --prefix="$BUILD/swig"
    make -j"$(sysctl -n hw.ncpu)"
    make install
  )
fi

# OCCT
if [ ! -d "$BUILD/OCCT-$OCCT_VERSION" ]; then
  curl -L -o "$BUILD/occt.tar.gz" \
    "https://github.com/Open-Cascade-SAS/OCCT/archive/refs/tags/V${OCCT_VERSION}.tar.gz"
  tar -xzf "$BUILD/occt.tar.gz" -C "$BUILD"
fi

cmake -S "$BUILD/OCCT-$OCCT_VERSION" -B "$BUILD/occt-build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DINSTALL_DIR="$PREFIX" \
  -DCMAKE_INSTALL_NAME_DIR="$PREFIX/lib" \
  -DBUILD_RELEASE_DISABLE_EXCEPTIONS=OFF \
  -DBUILD_MODULE_Draw=OFF \
  -DUSE_TK=OFF \
  -D3RDPARTY_FREETYPE_DIR="$(brew --prefix freetype)"

cmake --build "$BUILD/occt-build"
cmake --install "$BUILD/occt-build"

# pythonocc-core
if [ ! -d "$SRC" ]; then
  git clone --branch "$PYTHONOCC_VERSION" --depth 1 \
    https://github.com/tpaviot/pythonocc-core.git "$SRC"
fi
cp "$ROOT/setup.py" "$SRC/setup.py"

# Только Development.Module: модули не должны линковаться с libpython
sed -i.bak \
  -e 's/COMPONENTS Interpreter Development NumPy REQUIRED/COMPONENTS Interpreter Development.Module NumPy REQUIRED/' \
  -e 's/COMPONENTS Interpreter Development REQUIRED/COMPONENTS Interpreter Development.Module REQUIRED/' \
  "$SRC/CMakeLists.txt"
[ "$(grep -c 'Development.Module' "$SRC/CMakeLists.txt")" -eq 2 ]


cmake -S "$SRC" -B "$BUILD/pyocc-build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$BUILD/pyocc-install" \
  -DCMAKE_CXX_FLAGS="-Wno-error" \
  -DOCCT_INCLUDE_DIR="$PREFIX/include/opencascade" \
  -DOCCT_LIBRARY_DIR="$PREFIX/lib" \
  -DPYTHONOCC_INSTALL_DIRECTORY="$SRC/OCC" \
  -DPYTHONOCC_MESHDS_NUMPY=ON \
  -DPython3_EXECUTABLE="$PYTHON" \
  -DSWIG_EXECUTABLE="$SWIG"

# Заголовки rapidjson нужны обёртке RWGltf
export CPATH="$(brew --prefix rapidjson)/include"

ulimit -s 65520
cmake --build "$BUILD/pyocc-build" -j 8
cmake --install "$BUILD/pyocc-build"

# Колесо
rm -rf "$SRC/build" "$SRC/dist"
(cd "$SRC" && "$PYTHON" setup.py bdist_wheel)
"$ROOT/.venv/bin/delocate-wheel" -v -w "$ROOT/dist" "$SRC"/dist/*.whl
