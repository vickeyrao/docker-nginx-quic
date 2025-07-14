# https://hg.nginx.org/nginx-quic/file/tip/src/core/nginx.h
ARG NGINX_VERSION=1.29.0

# https://hg.nginx.org/nginx/
ARG NGINX_COMMIT=aff13bf32357

# https://github.com/google/ngx_brotli
ARG NGX_BROTLI_COMMIT=a71f9312c2deb28875acc7bacfdd5695a111aa53

# https://github.com/quictls/quictls
ARG QUICTLS_COMMIT=1ce079095c905dd0248362d695134bb308426e50

# https://github.com/openresty/headers-more-nginx-module#installation
ARG HEADERS_MORE_VERSION=0.37

# https://github.com/leev/ngx_http_geoip2_module/releases
ARG GEOIP2_VERSION=3.4

# https://github.com/tokers/zstd-nginx-module/releases
ARG ZSTD_VERSION=0.1.1

# https://hg.nginx.org/nginx-quic/file/quic/README#l75
ARG CONFIG="\
		--build=quic-$NGINX_COMMIT-quictls-$QUICTLS_COMMIT \
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--modules-path=/usr/lib/nginx/modules \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--pid-path=/var/run/nginx.pid \
		--lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
		--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
		--user=nginx \
		--group=nginx \
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_random_index_module \
		--with-http_secure_link_module \
		--with-http_stub_status_module \
		--with-http_auth_request_module \
		--with-http_xslt_module=dynamic \
		--with-http_image_filter_module=dynamic \
		--with-http_geoip_module=dynamic \
		--with-http_perl_module=dynamic \
		--with-threads \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
		--with-stream_geoip_module=dynamic \
		--with-http_slice_module \
		--with-mail \
		--with-mail_ssl_module \
		--with-compat \
		--with-file-aio \
		--with-http_v2_module \
		--with-http_v3_module \
		--add-module=/usr/src/ngx_brotli \
		--add-module=/usr/src/headers-more-nginx-module-$HEADERS_MORE_VERSION \
  		--add-module=/usr/src/zstd \
		--add-dynamic-module=/ngx_http_geoip2_module \
	"

FROM alpine:3.22.0 AS base
LABEL maintainer="NGINX Docker Maintainers <docker-maint@nginx.com>"

ARG NGINX_VERSION
ARG NGINX_COMMIT
ARG NGX_BROTLI_COMMIT

ARG HEADERS_MORE_VERSION
ARG CONFIG
ARG QUICTLS_COMMIT
ARG ZSTD_VERSION
ARG GEOIP2_VERSION

RUN \
	apk add --no-cache --virtual .build-deps \
		gcc \
		make \
		mercurial \
		pcre2-dev \
		zlib-dev \
		linux-headers \
		libxslt-dev \
		gd-dev \
		geoip-dev \
		perl-dev \
  	&& apk add --no-cache --virtual .geoip2-build-deps \
		libmaxminddb-dev \
	&& apk add --no-cache --virtual .brotli-build-deps \
   		cmake \
     		ninja \
		git \
		g++ \
  	&& apk add --no-cache --virtual .zstd-build-deps \
		zstd-dev

WORKDIR /usr/src/

RUN \
	echo "Cloning nginx $NGINX_VERSION (rev $NGINX_COMMIT from 'default' branch) ..." \
	&& hg clone -b default --rev $NGINX_COMMIT https://hg.nginx.org/nginx-quic /usr/src/nginx-$NGINX_VERSION

RUN \
	echo "Cloning brotli $NGX_BROTLI_COMMIT ..." \
	&& mkdir /usr/src/ngx_brotli \
	&& cd /usr/src/ngx_brotli \
	&& git init \
	&& git remote add origin https://github.com/google/ngx_brotli.git \
	&& git fetch --depth 1 origin $NGX_BROTLI_COMMIT \
	&& git checkout --recurse-submodules -q FETCH_HEAD \
	&& git submodule update --init --depth 1

RUN \
  echo "Cloning quictls ..." \
  && cd /usr/src \
  && git clone https://github.com/quictls/quictls \
  && cd quictls \
  && git checkout $QUICTLS_COMMIT

RUN \
  echo "Building quictls ..." \
  && cd /usr/src/quictls \
  && mkdir build \
  && cd build \
  && cmake -GNinja \
  && ninja

RUN \
  echo "Downloading headers-more-nginx-module ..." \
  && cd /usr/src \
  && wget https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/v${HEADERS_MORE_VERSION}.tar.gz -O headers-more-nginx-module.tar.gz \
  && tar -xf headers-more-nginx-module.tar.gz

RUN \
  echo "Downloading ngx_http_geoip2_module ..." \
  && git clone --depth 1 --branch ${GEOIP2_VERSION} https://github.com/leev/ngx_http_geoip2_module /usr/src/ngx_http_geoip2_module

RUN \
  echo "Downloading zstd-nginx-module ..." \
  && git clone --depth 1 --branch ${ZSTD_VERSION} https://github.com/tokers/zstd-nginx-module.git /usr/src/zstd

RUN \
  echo "Building nginx ..." \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& ./auto/configure $CONFIG \
	--with-cc-opt="-I /usr/src/quictls/build/include" \
	--with-ld-opt="-L /usr/src/quictls/build/lib" \
	&& make -j$(getconf _NPROCESSORS_ONLN)

RUN \
	cd /usr/src/nginx-$NGINX_VERSION \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	\
	# https://tools.ietf.org/html/rfc7919
	# https://github.com/mozilla/ssl-config-generator/blob/master/docs/ffdhe2048.txt
	&& wget -q https://ssl-config.mozilla.org/ffdhe2048.txt -O /etc/ssl/dhparam.pem \
	\
	# Bring in gettext so we can get `envsubst`, then throw
	# the rest away. To do this, we need to install `gettext`
	# then move `envsubst` out of the way so `gettext` can
	# be deleted completely, then move `envsubst` back.
	&& apk add --no-cache --virtual .gettext gettext \
	\
	&& scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /usr/bin/envsubst \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u > /tmp/runDeps.txt

FROM alpine:3.22.0
ARG NGINX_VERSION
ARG NGINX_COMMIT

ENV NGINX_VERSION $NGINX_VERSION
ENV NGINX_COMMIT $NGINX_COMMIT

COPY --from=base /tmp/runDeps.txt /tmp/runDeps.txt
COPY --from=base /etc/nginx /etc/nginx
COPY --from=base /usr/lib/nginx/modules/*.so /usr/lib/nginx/modules/
COPY --from=base /usr/sbin/nginx /usr/sbin/
COPY --from=base /usr/local/lib/perl5/site_perl /usr/local/lib/perl5/site_perl
COPY --from=base /usr/bin/envsubst /usr/local/bin/envsubst
COPY --from=base /etc/ssl/dhparam.pem /etc/ssl/dhparam.pem

RUN \
	addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G users -u 1000 user \
	&& apk add --no-cache --virtual .nginx-rundeps tzdata $(cat /tmp/runDeps.txt) \
	&& rm /tmp/runDeps.txt \
	&& ln -s /usr/lib/nginx/modules /etc/nginx/modules \
	# forward request and error logs to docker log collector
	&& mkdir /var/log/nginx \
	&& touch /var/log/nginx/access.log /var/log/nginx/error.log \
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

COPY nginx.conf /etc/nginx/nginx.conf
COPY ssl_common.conf /etc/nginx/conf.d/ssl_common.conf

# show env
RUN env | sort

# test the configuration
RUN nginx -V; nginx -t

EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
