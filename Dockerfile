FROM static-ffmpeg

FROM alpine

LABEL maintainer="Yongsheng Zhu <aone75@gmail.com>"

# Versions of Nginx and nginx-rtmp-module to use
ENV NGINX_VERSION nginx-1.21.6
ENV NGINX_RTMP_MODULE_VERSION 1.2.2
# Common dependencies
ENV DEPS_COMMON="bash nano lua"
# Common build tools
ENV DEPS_BUILD_TOOLS="git perl unzip gcc binutils build-base libgcc make pkgconf pkgconfig openssl openssl-dev ca-certificates pcre nasm yasm yasm-dev coreutils musl-dev libc-dev pcre-dev zlib-dev lua-dev"

# Use tuna mirror
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories

# Updating certificates
RUN apk update \
  && apk add openssl ca-certificates \
  && update-ca-certificates

# Installing common dependencies
RUN apk update && apk add --virtual .common-dependencies ${DEPS_COMMON}

# Installing build dependencies
RUN	apk update && apk add --virtual .build-dependencies	${DEPS_BUILD_TOOLS}

# Download and decompress Nginx
RUN mkdir -p /tmp/build/nginx && \
    cd /tmp/build/nginx && \
    wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxf ${NGINX_VERSION}.tar.gz

# Download and decompress RTMP module
RUN mkdir -p /tmp/build/nginx-rtmp-module && \
    cd /tmp/build/nginx-rtmp-module && \
    wget -O nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz https://github.com/arut/nginx-rtmp-module/archive/refs/tags/v${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    tar -zxf nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    cd nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}

# Build and install Nginx
# The default puts everything under /usr/local/nginx, so it's needed to change
# it explicitly. Not just for order but to have it in the PATH
RUN cd /tmp/build/nginx/${NGINX_VERSION} && \
    ./configure \
        --sbin-path=/usr/local/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx/nginx.pid \
        --lock-path=/var/lock/nginx/nginx.lock \
        --http-log-path=/var/log/nginx/access.log \
        --http-client-body-temp-path=/tmp/nginx-client-body \
        --with-http_ssl_module \
        --with-threads \
        --with-ipv6 \
        --add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION} && \
    make -j $(getconf _NPROCESSORS_ONLN) && \
    make install && \
    mkdir /var/lock/nginx && \
    rm -rf /tmp/build

# Forward logs to Docker
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Set up config file
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 1935
CMD ["nginx", "-g", "daemon off;"]
