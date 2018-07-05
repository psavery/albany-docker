FROM library/ubuntu:18.04 AS build
MAINTAINER Kitware <kitware@kitware.com>

SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get -y install \
  wget \
  git \
  g++ \
  gfortran \
  python \
  cmake \
  libblas-dev \
  liblapack-dev \
  libboost-system-dev \
  libboost-program-options-dev \
  libboost-signals-dev \
  libhdf5-mpich-dev \
  libmpich-dev \
  libpnetcdf-dev \
  libcurl4-openssl-dev \
  m4

RUN mkdir -p source && \
  pushd . && \
  cd source && \
  git clone https://github.com/psavery/netcdf-patch && \
  wget https://github.com/Unidata/netcdf-c/archive/v4.6.0.tar.gz && \
  tar -xzf v4.6.0.tar.gz && \
  cd netcdf-c-4.6.0 && \
  patch include/netcdf.h ../netcdf-patch/netcdf.h.patch && \
  grep -B 8 -A 2 "#define NC_MAX_VAR_DIMS" include/netcdf.h && \
  ./configure CC=mpicc FC=mpifort CXX=mpicxx \
  CFLAGS="-fPIC -I/usr/include/hdf5/mpich -march=native -O3" \
  CXXFLAGS="-fPIC -I/usr/include/hdf5/mpich -march=native -O3" \
  FCFLAGS="-fPIC -march=native -Wa,-q -O3" \
  LDFLAGS="-L/usr/lib/x86_64-linux-gnu/hdf5/mpich" \
  --disable-fsync --disable-doxygen --enable-netcdf4 --enable-pnetcdf \
  --prefix=/source/netcdf-install && \
  make -j "$(nproc)" install && \
  cp -r /source/netcdf-install/* /usr/

RUN mkdir -p source && \
  pushd . && \
  cd source && \
  git clone https://github.com/trilinos/Trilinos.git trilinos && \
  cd trilinos && \
  git checkout f54a04bf && \
  popd && \
  mkdir -p build/trilinos && \
  cd build/trilinos && \
  ls ../../source/trilinos/sampleScripts/AlbanySettings.cmake && \
  cmake \
    -DTrilinos_CONFIGURE_OPTIONS_FILE:FILEPATH=../../source/trilinos/sampleScripts/AlbanySettings.cmake \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -DTPL_ENABLE_MPI:BOOL=ON \
    -DTrilinos_ENABLE_TriKota:BOOL=OFF \
    -DTrilinos_ENABLE_STKTransfer:BOOL=OFF \
    -DTrilinos_ENABLE_MiniTensor:BOOL=ON \
    -DTrilinos_ENABLE_ROL:BOOL=ON \
    -DTrilinos_ENABLE_Tempus:BOOL=ON \
    -DTrilinos_ENABLE_TpetraTSQR:BOOL=ON \
    -DAnasazi_ENABLE_RBGen:BOOL=ON \
    -DTPL_ENABLE_X11=OFF \
    -DCMAKE_INSTALL_PREFIX:PATH=/usr/local/trilinos \
    ../../source/trilinos && \
  make -j "$(nproc)" install

RUN pushd . && \
  cd source && \
  git clone https://github.com/gahansen/Albany.git albany && \
  cd albany && \
  git checkout 1bc97775 && \
  popd && \
  mkdir -p build/albany && \
  cd build/albany && \
  cmake \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -DALBANY_TRILINOS_DIR:FILEPATH="/usr/local/trilinos" \
    -DENABLE_LCM:BOOL=ON \
    -DENABLE_AERAS:BOOL=OFF \
    -DENABLE_QCAD:BOOL=OFF \
    -DENABLE_HYDRIDE:BOOL=OFF \
    -DENABLE_LCM_SPECULATIVE:BOOL=OFF \
    -DENABLE_LAME:BOOL=OFF \
    -DENABLE_DEBUGGING:BOOL=OFF \
    -DENABLE_CHECK_FPE:BOOL=OFF \
    -DENABLE_SCOREC:BOOL=OFF \
    -DENABLE_FELIX:BOOL=OFF \
    -DENABLE_MOR:BOOL=OFF \
    -DENABLE_ALBANY_CI:BOOL=OFF \
    -DENABLE_ASCR:BOOL=OFF \
    -DENABLE_PERFORMANCE_TESTS:BOOL=OFF \
    -DENABLE_64BIT_INT:BOOL=ON \
    -DCMAKE_INSTALL_PREFIX:PATH=/usr/local/albany \
    -DENABLE_INSTALL:BOOL=ON \
    ../../source/albany && \
  make -j "$(nproc)" install

# Create new image
FROM library/ubuntu:18.04

# Install runtime deps
RUN apt-get update && apt-get -y install \
  libblas3 \
  liblapack3 \
  libboost-program-options1.65 \
  libhdf5-mpich-100 \
  libmpich12 \
  libpnetcdf0d \
  libcurl4

# Copy netcdf from build image
COPY --from=build /source/netcdf-install /usr/

# Copy Trilinos from build image
COPY --from=build /usr/local/trilinos /usr/local/trilinos

# Copy Albany from build image
COPY --from=build /usr/local/albany /usr/local/albany

ENTRYPOINT ["/usr/local/albany/bin/Albany"]

ARG BUILD_DATE
ARG IMAGE=albany
ARG VCS_REF
ARG VCS_URL
LABEL org.label-schema.build-date=BUILD_DATE \
      org.label-schema.name=$IMAGE \
      org.label-schema.description="Albany multiphysics code" \
      org.label-schema.url="" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url=$VCS_URL \
      org.label-schema.schema-version="1.0"
