FROM quay.io/pypa/manylinux_2_28_x86_64

ENV OCCT_VERSION=7_9_3
ENV SWIG_VERSION=4.2.1
ENV OUTPUT_DIR=/dist
ENV PYTHONOCC_INSTALL_DIRECTORY=/workspace/pythonocc-core/OCC

# Только базовые системные зависимости, необходимые для компиляции C++ и X11/Tcl
RUN dnf install -y \
    wget git cmake make gcc gcc-c++ \
    libX11-devel libXext-devel libXmu-devel libXi-devel \
    libXt-devel libXft-devel \
    mesa-libGL-devel mesa-libGLU-devel \
    fontconfig-devel freetype-devel \
    tcl-devel tk-devel \
    flex bison pcre2-devel \
    rapidjson-devel \
    gcc-toolset-13 \
    && dnf clean all

RUN /opt/python/cp311-cp311/bin/pip install numpy

WORKDIR /workspace

# 1. Сборка SWIG
RUN wget https://prdownloads.sourceforge.net/swig/swig-${SWIG_VERSION}.tar.gz && \
    tar -zxvf swig-${SWIG_VERSION}.tar.gz && \
    cd swig-${SWIG_VERSION} && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) -O && \
    make install && \
    cd .. && rm -rf swig-${SWIG_VERSION} swig-${SWIG_VERSION}.tar.gz

# 2. Сборка OpenCASCADE (OCCT)
RUN wget https://github.com/Open-Cascade-SAS/OCCT/archive/refs/tags/V${OCCT_VERSION}.tar.gz && \
    tar -xvzf V${OCCT_VERSION}.tar.gz && \
    cd OCCT-${OCCT_VERSION} && \
    mkdir cmake-build && cd cmake-build && \
    cmake -DINSTALL_DIR=/opt/occt793 \
          -DBUILD_RELEASE_DISABLE_EXCEPTIONS=OFF \
          .. && \
    make -j$(nproc) -O && \
    make install && \
    cd ../.. && rm -rf OCCT-${OCCT_VERSION} V${OCCT_VERSION}.tar.gz

# Регистрация библиотек в системе (необходимо для финальной упаковки wheel)
RUN echo "/opt/occt793/lib" > /etc/ld.so.conf.d/occt.conf && ldconfig

# 3. Сборка pythonocc-core
RUN git clone --branch 7.9.3 --depth 1 https://github.com/tpaviot/pythonocc-core.git
COPY setup.py /workspace/pythonocc-core/setup.py

# Manylinux-сборка CPython не содержит libpython (ни shared, ни static),
# поэтому просим CMake искать только Development.Module, без Development.Embed
RUN sed -i \
    -e 's/COMPONENTS Interpreter Development NumPy REQUIRED/COMPONENTS Interpreter Development.Module NumPy REQUIRED/' \
    -e 's/COMPONENTS Interpreter Development REQUIRED/COMPONENTS Interpreter Development.Module REQUIRED/' \
    /workspace/pythonocc-core/CMakeLists.txt



RUN cd /workspace/pythonocc-core && \
    mkdir -p cmake-build && cd cmake-build && \
    source /opt/rh/gcc-toolset-13/enable && \
    cmake -DOCCT_INCLUDE_DIR=/opt/occt793/include/opencascade \
          -DOCCT_LIBRARY_DIR=/opt/occt793/lib \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CXX_FLAGS="-Wno-error -std=c++17" \
          -DCMAKE_C_COMPILER=/opt/rh/gcc-toolset-13/root/usr/bin/gcc \
          -DCMAKE_CXX_COMPILER=/opt/rh/gcc-toolset-13/root/usr/bin/g++ \
          -DPYTHONOCC_INSTALL_DIRECTORY=$PYTHONOCC_INSTALL_DIRECTORY \
          -DPython3_EXECUTABLE=/opt/python/cp311-cp311/bin/python \
          -DPython3_INCLUDE_DIR=/opt/python/cp311-cp311/include/python3.11 \
          -DPYTHONOCC_MESHDS_NUMPY=ON \
          .. && \
    ulimit -s unlimited && \
    make -j$(nproc) && \
    make install


# 4. Упаковка в .whl (для требования "не привязан к типу Linux")
RUN /opt/python/cp311-cp311/bin/python -m pip install --upgrade pip wheel setuptools auditwheel

RUN cd /workspace/pythonocc-core && \
    /opt/python/cp311-cp311/bin/python setup.py bdist_wheel && \
    /opt/python/cp311-cp311/bin/python -m auditwheel repair dist/*.whl --plat manylinux_2_28_x86_64 -w ${OUTPUT_DIR}


# запуск сборки
# docker build -f linux/Dockerfile -t pythonocc-wheel-builder .

# копирование пакета из контейнера в директорию на хосте
# пример команды для копирования:

# docker create --name wheel-extract pythonocc-wheel-builder:latest
# docker cp wheel-extract:/dist ./dist
# docker rm wheel-extract
