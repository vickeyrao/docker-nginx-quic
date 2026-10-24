## What is this?

Forked from [macbre/nginx-http3](https://github.com/macbre/docker-nginx-http3)

Stable and up-to-date [Nginx](https://nginx.org/en/CHANGES) with [QUIC + HTTP/3 support](https://nginx.org/en/docs/http/ngx_http_v3_module.html), [Google's `brotli` compression](https://github.com/google/ngx_brotli), [`zstd` compression](https://github.com/tokers/zstd-nginx-module), and [Grade A+ SSL config](https://ssl-config.mozilla.org/).

The binary is built from the [official Nginx source](https://github.com/nginx/nginx), with support for the QUIC/HTTP/3 stack and a curated set of compression and HTTP modules.

## How to use this image

This project follows the same container conventions as the official [nginx image](https://hub.docker.com/_/nginx/). In addition to the standard nginx directives, you can use the module-specific config options documented upstream for brotli, GeoIP2, and other included extensions.

Pull the image:

```bash
docker pull ghcr.io/vickeyrao/docker-nginx-quic:latest
# or
# docker pull vickeyrao/docker-nginx-quic:latest
```

Run it with a basic HTTP/HTTPS setup:

```bash
docker run --rm \
  -p 0.0.0.0:80:80 \
  -p 0.0.0.0:443:443/tcp \
  -p 0.0.0.0:443:443/udp \
  ghcr.io/vickeyrao/docker-nginx-quic:latest
```

For a complete example using TLS certs and test configs, see the included `run-docker.sh` script in this repository.

## What's inside

* [built-in nginx modules](https://nginx.org/en/docs/)
* [`headers-more-nginx-module`](https://github.com/openresty/headers-more-nginx-module#readme) - sets and clears HTTP request and response headers
* [`ngx_brotli`](https://github.com/google/ngx_brotli#configuration-directives) - adds [brotli response compression](https://datatracker.ietf.org/doc/html/rfc7932)
* [`ngx_http_geoip2_module`](https://github.com/leev/ngx_http_geoip2_module#download-maxmind-geolite2-database-optional) - creates variables from MaxMind GeoIP2 databases based on the client IP
* [`OpenSSL with QUIC APIs`](https://github.com/openssl/openssl) - an OpenSSL build with QUIC-ready APIs and HTTP/3 support
* [`zstd-nginx-module`](https://github.com/tokers/zstd-nginx-module) - adds zstd compression for HTTP responses

The current build is pinned to:

- nginx `1.31.8`
- OpenSSL `4.1.0`
- `headers-more-nginx-module` `0.40`
- `ngx_http_geoip2_module` `3.4`
- `zstd-nginx-module` `0.1.1`

Example runtime output:

```bash
$ docker run --rm ghcr.io/vickeyrao/docker-nginx-quic:latest nginx -V
nginx version: nginx/1.31.8 (quic-OpenSSL-4.1.0)
built by gcc 14.2.0 (Alpine 3.24.3)
built with OpenSSL 4.1.0
TLS SNI support enabled
configure arguments:
  --prefix=/etc/nginx
  --sbin-path=/usr/sbin/nginx
  --modules-path=/usr/lib/nginx/modules
  --conf-path=/etc/nginx/nginx.conf
  --with-http_ssl_module
  --with-http_v2_module
  --with-http_v3_module
  --add-module=/usr/src/ngx_brotli
  --add-module=/usr/src/headers-more-nginx-module-0.40
  --add-module=/usr/src/zstd
  --add-dynamic-module=/usr/src/ngx_http_geoip2_module
  --with-openssl=../openssl
```

## SSL Grade A+ handling

Please refer to [Mozilla's SSL Configuration Generator](https://ssl-config.mozilla.org/). This image has `https://ssl-config.mozilla.org/ffdhe2048.txt` DH parameters for DHE ciphers fetched and stored in `/etc/ssl/dhparam.pem`:

```
    ssl_dhparam /etc/ssl/dhparam.pem;
```

See [ssllabs.com test results for wbc.macbre.net](https://www.ssllabs.com/ssltest/analyze.html?d=wbc.macbre.net).

## nginx config files includes

* `.conf` files mounted in `/etc/nginx/main.d` will be included in the `main` nginx context (e.g. you can call [`env` directive](http://nginx.org/en/docs/ngx_core_module.html#env) there)
* `.conf` files mounted in `/etc/nginx/conf.d` will be included in the `http` nginx context

## QUIC + HTTP/3 support

<img width="577" alt="Screenshot 2021-05-19 at 16 31 10" src="https://user-images.githubusercontent.com/1929317/118840921-baf7d300-b8bf-11eb-8c0f-e57d573a28ce.png">

Please refer to `tests/https.conf` config file for an example config used by the tests. And to Cloudflare docs on [how to enable http/3 support in your browser](https://developers.cloudflare.com/http3/firefox).

```
server {
    # http/3
    listen 443 quic reuseport;

    # http/2 and http/1.1
    listen 443 ssl;

    http2 on;	
    server_name localhost;  # customize to match your domain

    # you need to mount these files when running this container
    ssl_certificate     /etc/nginx/ssl/localhost.crt;
    ssl_certificate_key /etc/nginx/ssl/localhost.key;

    # Enable all TLS versions (TLSv1.3 is required for QUIC).
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;

    # 0-RTT QUIC connection resumption
    ssl_early_data on;

    # Add Alt-Svc header to negotiate HTTP/3.
    add_header alt-svc 'h3=":443"; ma=86400';

    location / {
        # your config
    }
}
```

Refer to `run-docker.sh` script on how to run this container and properly mount required config files and assets.
