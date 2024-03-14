FROM httpd:2.4-alpine

RUN python3 -m pip install --upgrade pip

# Update Alpine packages and install necessary dependencies
RUN apk update && apk upgrade && \
    apk add --no-cache \
        curl \
        openssl \
        python3 \
        py3-pip \
        gcc \
        libc-dev \
        apache2-dev \
        apr-dev \
        apr-util-dev \
        libffi-dev \
        tzdata

# Install Flask, PyYAML, and mod_wsgi using pip
RUN pip3 install Flask pyyaml==6.0.1 mod_wsgi

# Set up SSL certificates
RUN mkdir -p /etc/tls && \
    cd /etc/tls && \
    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
        -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=localhost" \
        -keyout key.pem -out cert.pem

# Set up Apache configurations
COPY resources/bahmni-proxy.conf /usr/local/apache2/conf/
RUN echo "Include conf/bahmni-proxy.conf" >> /usr/local/apache2/conf/httpd.conf
RUN sed -i "s/Options Indexes FollowSymLinks/Options -Indexes +FollowSymLinks/" /usr/local/apache2/conf/httpd.conf

# Copy static files and scripts
COPY resources/index.html /usr/local/apache2/htdocs/index.html
COPY resources/systemdate.sh /usr/local/apache2/cgi-bin/systemdate
COPY resources/bahmni-logo.png /usr/local/apache2/htdocs/bahmni-logo.png
COPY resources/favicon.png /usr/local/apache2/htdocs/favicon.png
COPY resources/maintenance.html /usr/local/apache2/htdocs/maintenance.html
COPY resources/unauthorized.html /usr/local/apache2/htdocs/unauthorized.html
COPY resources/internalError.html /usr/local/apache2/htdocs/internalError.html
COPY resources/style.css /usr/local/apache2/htdocs/style.css
COPY resources/src.jpeg /usr/local/apache2/htdocs/src.jpeg

# Create directory for mod_proxy cache
RUN mkdir -p /var/cache/mod_proxy

# Set up client-side logging
RUN mkdir -p /var/log/client-side-logs/ && \
    touch /var/log/client-side-logs/client-side.log && \
    chmod 777 /var/log/client-side-logs/client-side.log && \
    ln -s /usr/local/apache2/htdocs/client_side_logging /usr/lib/python3*/site-packages/

# Set up Certbot
RUN python3 -m venv /opt/certbot/ && \
    /opt/certbot/bin/pip install certbot && \
    ln -s /opt/certbot/bin/certbot /usr/bin/certbot

# Clean up unnecessary files and packages
RUN rm -rf /usr/local/apache2/cgi-bin/test-cgi \
    && rm -rf /usr/local/apache2/cgi-bin/printenv* \
    && rm -rf /var/cache/apk/*

# Move mod_wsgi module to Apache modules directory
RUN mv /usr/lib/python*/site-packages/mod_wsgi/server/mod_wsgi-*.so /usr/local/apache2/modules/mod_wsgi.so
