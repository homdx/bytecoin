# Use Alpine 3.8 docker image
# Multistage docker build, requires docker 17.05
FROM alpine as builder

RUN apk update && apk add boost-dev cmake make gcc musl-dev linux-headers openssl-dev git wget bzip2-dev build-base gcc curl

WORKDIR /app

ARG BOOST_VERSION=1_68_0
ARG BOOST_VERSION_DOT=1.68.0
ARG BOOST_HASH=7f6130bc3cf65f56a618888ce9d5ea704fa10b462be126ad053e80e553d6d8b7
RUN set -ex \
    &&  curl -s -L -o  boost_${BOOST_VERSION}.tar.bz2 https://dl.bintray.com/boostorg/release/${BOOST_VERSION_DOT}/source/boost_${BOOST_VERSION}.tar.bz2 \
    && echo "${BOOST_HASH}  boost_${BOOST_VERSION}.tar.bz2" | sha256sum -c \
    && tar -xvf boost_${BOOST_VERSION}.tar.bz2 \
    && mv boost_${BOOST_VERSION} boost \
    && cd boost \
    && ./bootstrap.sh \
    && ./b2 --build-type=minimal link=static -j4 runtime-link=static --with-chrono --with-date_time --with-filesystem --with-program_options --with-regex --with-serialization --with-system --with-thread --stagedir=stage threading=multi threadapi=pthread cflags="-fPIC" cxxflags="-fPIC" stage

# LMDB
ARG LMDB_VERSION=LMDB_0.9.22
ARG LMDB_HASH=5033a08c86fb6ef0adddabad327422a1c0c0069a
RUN set -ex \
    && git clone https://github.com/LMDB/lmdb.git -b ${LMDB_VERSION} \
    && cd lmdb \
    && test `git rev-parse HEAD` = ${LMDB_HASH} || exit 1

ENV test=1
#COPY . /app/bytecoin
RUN cd /app && git clone https://github.com/bcndev/bytecoin.git

RUN set -ex \
    && mkdir /app/bytecoin/build \
    && cd bytecoin/build \
    && cmake .. \
    && time make -j4 \
    && cp -v ../bin/* /usr/local/bin \
    && mkdir /usr/local/bin/wallet_file \
    && cp -v ../tests/wallet_file/* /usr/local/bin/wallet_file \
    && echo '[ SHOW VERSION ]' \
    && bytecoind -v

# If you have an old version of the docker:
# (not supported Multistage docker build)
# Please comment all the lines below this!

FROM alpine

RUN set -ex \
    && apk update \
    && apk add --no-cache libstdc++ openssl

COPY --from=builder /usr/local/bin/* /usr/local/bin/

RUN ls -la /usr/local/bin/ \
    && mkdir -p /tests/wallet_file \
    && cp /usr/local/bin/*.wallet /tests/wallet_file/ \
    && cd /tests && tests \
    && echo '[ SHOW VERSION ]' \
    && bytecoind -v && cd tests && tests
