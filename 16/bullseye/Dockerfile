#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM debian:bullseye-slim

# explicitly set user/group IDs
RUN set -eux; \
	groupadd -r postgres --gid=999; \
# https://salsa.debian.org/postgresql/postgresql-common/blob/997d842ee744687d99a2b2d95c1083a2615c79e8/debian/postgresql-common.postinst#L32-35
	useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
# also create the postgres user's home directory with appropriate permissions
# see https://github.com/docker-library/postgres/issues/274
	install --verbose --directory --owner postgres --group postgres --mode 1777 /var/lib/postgresql

RUN set -ex; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		gnupg \
# https://www.postgresql.org/docs/16/app-psql.html#APP-PSQL-META-COMMAND-PSET-PAGER
# https://github.com/postgres/postgres/blob/REL_16_1/src/include/fe_utils/print.h#L25
# (if "less" is available, it gets used as the default pager for psql, and it only adds ~1.5MiB to our image size)
		less \
	; \
	rm -rf /var/lib/apt/lists/*

# grab gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.17
RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates wget; \
	rm -rf /var/lib/apt/lists/*; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
RUN set -eux; \
	if [ -f /etc/dpkg/dpkg.cfg.d/docker ]; then \
# if this file exists, we're likely in "debian:xxx-slim", and locales are thus being excluded so we need to remove that exclusion (since we need locales)
		grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
		sed -ri '/\/usr\/share\/locale/d' /etc/dpkg/dpkg.cfg.d/docker; \
		! grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
	fi; \
	apt-get update; apt-get install -y --no-install-recommends locales; rm -rf /var/lib/apt/lists/*; \
	echo 'ru_RU.UTF-8 UTF-8' >> /etc/locale.gen; \
	echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen; \
	locale-gen; \
	locale -a | grep 'ru_RU.utf8'
ENV LANG ru_RU.utf8

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libnss-wrapper \
		xz-utils \
		zstd \
	; \
	rm -rf /var/lib/apt/lists/*

RUN mkdir /docker-entrypoint-initdb.d

ENV PG_MAJOR 16
ENV PATH $PATH:/usr/lib/postgresql/$PG_MAJOR/bin

ENV PG_VERSION 16.2-3.1C

ENV DEBIAN_MAJOR 11

# Скачиваем дистрибутивы и зависимости
ARG ITS_USER
ARG ITS_PASSWORD

# libxml2-utils curl jq нужны для загрузки дистрибутивов с releases, lbzip2 для распаковки
RUN	set -eux; \
	apt update; \
	apt install lbzip2 libxml2-utils curl jq -y

RUN mkdir /tmp/pg_install
COPY 1c-client.sh /tmp/pg_install
RUN chmod +x /tmp/pg_install/1c-client.sh

RUN set -eux; \
	EXTRAFILES_FILE="debian${DEBIAN_MAJOR}.x86_64.tar.gz"; \
	EXTRAFILES_PATH="/additional_file?nick=AddCompPostgre&path=AddCompPostgre%5cExtrafiles%5c$EXTRAFILES_FILE"; \
	/tmp/pg_install/1c-client.sh -u "$ITS_USER" -p "$ITS_PASSWORD" -f "/tmp/pg_install/$EXTRAFILES_FILE" "$EXTRAFILES_PATH"; \
	PG_VERSION_FILE=$(echo ${PG_VERSION} | sed "s/-/_/"); \
	PG_VERSION_PATH=$(echo ${PG_VERSION_FILE} | sed "s/\./_/g"); \
	PGDISTRO_FILE="postgresql_${PG_VERSION_FILE}_amd64_deb.tar.bz2"; \
	PGDISTRO_PATH="/version_file?nick=AddCompPostgre&ver=${PG_VERSION}&path=AddCompPostgre%5c${PG_VERSION_PATH}%5c$PGDISTRO_FILE"; \
	/tmp/pg_install/1c-client.sh -u "$ITS_USER" -p "$ITS_PASSWORD" -f "/tmp/pg_install/$PGDISTRO_FILE" "$PGDISTRO_PATH"

# Устанавливаем
RUN set -eux; \
	for file in /tmp/pg_install/*tar*; do tar -xf "$file" -C /tmp/pg_install; done ; \
	ls -l /tmp/pg_install/; \
	apt update; \
	apt install /tmp/pg_install/libs${PG_MAJOR}/*.deb -y --allow-downgrades; \
	apt install /tmp/pg_install/postgresql-${PG_VERSION}_amd64_deb/*.deb -y --allow-downgrades

RUN apt-mark hold libpq5:amd64 postgresql-${PG_MAJOR} postgresql-client-${PG_MAJOR}

# Удаляем лишнее
RUN set -eux; \
	rm -rf /tmp/pg_install; \
	rm -rf /var/lib/apt/lists/*

# make the sample config easier to munge (and "correct by default")
RUN set -eux; \
	dpkg-divert --add --rename --divert "/usr/share/postgresql/postgresql.conf.sample.dpkg" "/usr/share/postgresql/$PG_MAJOR/postgresql.conf.sample"; \
	cp -v /usr/share/postgresql/postgresql.conf.sample.dpkg /usr/share/postgresql/postgresql.conf.sample; \
	ln -sv ../postgresql.conf.sample "/usr/share/postgresql/$PG_MAJOR/"; \
	sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/share/postgresql/postgresql.conf.sample; \
	grep -F "listen_addresses = '*'" /usr/share/postgresql/postgresql.conf.sample

RUN install --verbose --directory --owner postgres --group postgres --mode 3777 /var/run/postgresql

ENV PGDATA /var/lib/postgresql/data
# this 1777 will be replaced by 0700 at runtime (allows semi-arbitrary "--user" values)
RUN install --verbose --directory --owner postgres --group postgres --mode 1777 "$PGDATA"
VOLUME /var/lib/postgresql/data

COPY docker-entrypoint.sh docker-ensure-initdb.sh /usr/local/bin/
RUN ln -sT docker-ensure-initdb.sh /usr/local/bin/docker-enforce-initdb.sh
ENTRYPOINT ["docker-entrypoint.sh"]

# We set the default STOPSIGNAL to SIGINT, which corresponds to what PostgreSQL
# calls "Fast Shutdown mode" wherein new connections are disallowed and any
# in-progress transactions are aborted, allowing PostgreSQL to stop cleanly and
# flush tables to disk, which is the best compromise available to avoid data
# corruption.
#
# Users who know their applications do not keep open long-lived idle connections
# may way to use a value of SIGTERM instead, which corresponds to "Smart
# Shutdown mode" in which any existing sessions are allowed to finish and the
# server stops when all sessions are terminated.
#
# See https://www.postgresql.org/docs/12/server-shutdown.html for more details
# about available PostgreSQL server shutdown signals.
#
# See also https://www.postgresql.org/docs/12/server-start.html for further
# justification of this as the default value, namely that the example (and
# shipped) systemd service files use the "Fast Shutdown mode" for service
# termination.
#
STOPSIGNAL SIGINT
#
# An additional setting that is recommended for all users regardless of this
# value is the runtime "--stop-timeout" (or your orchestrator/runtime's
# equivalent) for controlling how long to wait between sending the defined
# STOPSIGNAL and sending SIGKILL (which is likely to cause data corruption).
#
# The default in most runtimes (such as Docker) is 10 seconds, and the
# documentation at https://www.postgresql.org/docs/12/server-start.html notes
# that even 90 seconds may not be long enough in many instances.

EXPOSE 5432
CMD ["postgres"]
