#!/bin/bash
set -e -u -x

function repair_wheel {
    wheel="$1"
    if ! auditwheel show "$wheel"; then
        echo "Skipping non-platform wheel $wheel"
    else
        auditwheel repair "$wheel" --plat "$PLAT" -w /io/wheelhouse/
    fi
}

yum install -y gcc gcc-c++ make
yum install -y git subversion
yum install -y boost boost-devel fftw-devel freetype freetype-devel giflib glew glew-devel jemalloc libX11-devel libXxf86vm-devel libXcursor-devel libXi-devel libXrandr-devel libXinerama-devel libjpeg-devel libpng-devel libsndfile libtiff libtiff-devel mesa-libGL mesa-libGL-devel OpenEXR OpenEXR-devel SDL SDL_image zlib zlib-devel openssl-devel bzip2-devel libffi-devel yasm

yum erase -y cmake

curl -L https://www.python.org/ftp/python/3.7.7/Python-3.7.7.tgz -o Python-3.7.7.tgz
tar xzf Python-3.7.7.tgz
cd Python-3.7.7
./configure --enable-optimizations
make install
cd ..

curl -L https://www.libraw.org/data/LibRaw-0.19.5.tar.gz -o LibRaw-0.19.5.tar.gz
tar xvzf LibRaw-0.19.5.tar.gz
cd LibRaw-0.19.5
./configure
make
make install
cd ..

curl -O -L https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
tar xjvf ffmpeg-snapshot.tar.bz2
cd ffmpeg
./configure --disable-x86asm
make
make install
cd ..

curl -L https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.12/hdf5-1.12.0/src/hdf5-1.12.0.tar.gz -o hdf5-1.12.0.tar.gz
tar xvzf hdf5-1.12.0.tar.gz
cd hdf5-1.12.0
./configure
make
make install
cd ..

wget http://ftp.gnu.org/gnu/glibc/glibc-2.14.tar.gz
tar zxvf glibc-2.14.tar.gz
cd glibc-2.14
mkdir build
cd build
../configure --prefix=/opt/glibc-2.14
make
make install
cd ../..

curl -L https://github.com/Kitware/CMake/releases/download/v3.17.3/cmake-3.17.3-Linux-x86_64.tar.gz -o cmake-3.17.3-Linux-x86_64.tar.gz
tar xvzf cmake-3.17.3-Linux-x86_64.tar.gz
PATH=$PATH:$(pwd)/cmake-3.17.3-Linux-x86_64/bin/

git clone https://github.com/AcademySoftwareFoundation/openvdb.git
cd openvdb
mkdir build
cd build
cmake ..
make
make install
cd ../..

git clone https://github.com/uclouvain/openjpeg.git
cd openjpeg
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make
make install
cd ../..

git clone -b release https://github.com/OpenImageIO/oiio.git
cd oiio
mkdir build
cd build
cmake ..
make
make install
cd ../..

# Compile wheels
for PYBIN in /opt/python/cp37*/bin; do
    PATH=$PATH:${PYBIN}
    "${PYBIN}/pip" install -r /io/requirements.txt
    cp /io/bpy/setup.py /io/setup.py
    "${PYBIN}/pip" wheel /io/ --no-deps -w wheelhouse/
    rm /io/setup.py
done

# Bundle external shared libraries into the wheels
for whl in wheelhouse/*.whl; do
    repair_wheel "$whl"
done

# Install packages and test
for PYBIN in /opt/python/*/bin/; do
    "${PYBIN}/pip" install python-manylinux-demo --no-index -f /io/wheelhouse
    (cd "$HOME"; "${PYBIN}/nosetests" pymanylinuxdemo)
done