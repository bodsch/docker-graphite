FROM alpine:3.9

ARG VCS_REF
ARG BUILD_DATE
ARG BUILD_VERSION
ARG BUILD_TYPE
ARG GRAPHITE_VERSION
ARG PYTHON_VERSION

ENV \
  TZ='Europe/Berlin' \
  TERM=xterm

# 2003: Carbon line receiver port
# 7002: Carbon cache query port
# 8080: Graphite-Web port
EXPOSE 2003 2003/udp 7002 8080

# ---------------------------------------------------------------------------------------

WORKDIR /tmp
# hadolint ignore=DL3003,DL3013,DL3017,DL3018,DL3019
RUN \
  echo "export BUILD_DATE=${BUILD_DATE}"              > /etc/profile.d/graphite.sh && \
  echo "export BUILD_TYPE=${BUILD_TYPE}"             >> /etc/profile.d/graphite.sh && \
  echo "export GRAPHITE_VERSION=${GRAPHITE_VERSION}" >> /etc/profile.d/graphite.sh && \
  apk update  --quiet && \
  apk upgrade --quiet && \
  apk add     --quiet --virtual .build-deps \
    build-base \
    git \
    libffi-dev \
    libressl-dev \
    "py${PYTHON_VERSION}-pip" \
    "python${PYTHON_VERSION}-dev" \
    tzdata && \
  apk add     --quiet \
    cairo \
    curl \
    mariadb-client \
    nginx \
    "python${PYTHON_VERSION}" \
    "py${PYTHON_VERSION}-cairo" \
    "py${PYTHON_VERSION}-parsing" && \
  if [ "${PYTHON_VERSION}" = 2 ] ; then \
    apk add   --quiet \
      supervisor \
      py-mysqldb && \
    "pip${PYTHON_VERSION}" install \
      --quiet \
      --trusted-host http://d.pypi.python.org/simple \
      --upgrade \
      pip ; \
  elif [ "${PYTHON_VERSION}" = 3 ] ; then \
    python3 -m ensurepip && \
    rm -r /usr/lib/python*/ensurepip && \
    pip3 install \
      --quiet \
      --upgrade \
      pip setuptools && \
    [ ! -e /usr/bin/pip ]    && ln -s pip3 /usr/bin/pip ; \
    [ ! -e /usr/bin/python ] && ln -sf /usr/bin/python3 /usr/bin/python ; \
    pip install \
      --quiet git+https://github.com/Supervisor/supervisor ; \
    pip install \
      --quiet pymysql ; \
  else \
    echo "wrong python version: ${PYTHON_VERSION}" ; \
    exit 1 ; \
  fi && \
  cp "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
  echo "${TZ}" > /etc/timezone && \
  git clone https://github.com/graphite-project/whisper.git      /tmp/whisper      && \
  git clone https://github.com/graphite-project/carbon.git       /tmp/carbon       && \
  git clone https://github.com/graphite-project/graphite-web.git /tmp/graphite-web && \
  if [ "${BUILD_TYPE}" = "stable" ] ; then \
    for i in whisper carbon graphite-web ; do \
      echo "switch to stable Tag ${GRAPHITE_VERSION} for $i" && \
      cd /tmp/$i ; \
      git checkout "tags/${GRAPHITE_VERSION}" 2> /dev/null ; \
    done ; \
  fi && \
  if [ "${PYTHON_VERSION}" = 3 ] ; then \
    sed -i 's|^python-memcached|# python-memcached|g' /tmp/graphite-web/requirements.txt; \
  fi && \
  cd /tmp/graphite-web &&  "pip${PYTHON_VERSION}" install --quiet --requirement requirements.txt && \
  cd /tmp/whisper      &&  python -W ignore::UserWarning:distutils.dist setup.py install --quiet > /dev/null && \
  cd /tmp/carbon       &&  python -W ignore::UserWarning:distutils.dist setup.py install --quiet > /dev/null && \
  cd /tmp/graphite-web &&  python -W ignore::UserWarning:distutils.dist setup.py install --quiet > /dev/null && \
  mv /opt/graphite/conf/graphite.wsgi.example /opt/graphite/webapp/graphite/graphite_wsgi.py && \
  mv /tmp/carbon/lib/carbon/tests/data/conf-directory/storage-aggregation.conf /opt/graphite/conf/storage-aggregation.conf-DIST && \
  mv /tmp/carbon/lib/carbon/tests/data/conf-directory/storage-schemas.conf     /opt/graphite/conf/storage-schemas.conf-DIST && \
  apk del --quiet .build-deps && \
  rm -rf \
    /src \
    /tmp/* \
    /root/.cache \
    /var/cache/apk/*

COPY rootfs/ /

WORKDIR /opt/graphite

VOLUME /srv

CMD ["/init/run.sh"]

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD curl --silent --fail http://localhost:8080 || exit 1

# ---------------------------------------------------------------------------------------

LABEL \
  version="${BUILD_VERSION}" \
  maintainer="Bodo Schulz <bodo@boone-schulz.de>" \
  org.label-schema.build-date=${BUILD_DATE} \
  org.label-schema.name="Graphite Docker Image" \
  org.label-schema.description="Inofficial Graphite Docker Image" \
  org.label-schema.url="https://graphite.readthedocs.io/en/latest/index.html" \
  org.label-schema.vcs-url="https://github.com/bodsch/docker-graphite" \
  org.label-schema.vcs-ref=${VCS_REF} \
  org.label-schema.vendor="Bodo Schulz" \
  org.label-schema.version=${GRAPHITE_VERSION} \
  org.label-schema.schema-version="1.0" \
  com.microscaling.docker.dockerfile="/Dockerfile" \
  com.microscaling.license="The Unlicense"

# ---------------------------------------------------------------------------------------
