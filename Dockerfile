FROM node:10.13.0

ENV npm_config_loglevel warn

#
# https://github.com/docker-library/ruby/blob/8954b9635b143504e2fa21459cc8ce809d388242/2.4/Dockerfile
#

# skip installing gem documentation
RUN mkdir -p /usr/local/etc \
	&& { \
	echo 'install: --no-document'; \
	echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc

ENV RUBY_MAJOR 2.4
ENV RUBY_VERSION 2.4.1
ENV RUBY_DOWNLOAD_SHA256 4fc8a9992de3e90191de369270ea4b6c1b171b7941743614cc50822ddc1fe654
ENV RUBYGEMS_VERSION 2.6.12

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
RUN set -ex \
	\
	&& buildDeps=' \
	bison \
	dpkg-dev \
	libgdbm-dev \
	ruby \
	' \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends $buildDeps \
	&& rm -rf /var/lib/apt/lists/* \
	\
	&& wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz" \
	&& echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum -c - \
	\
	&& mkdir -p /usr/src/ruby \
	&& tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1 \
	&& rm ruby.tar.xz \
	\
	&& cd /usr/src/ruby \
	\
	# hack in "ENABLE_PATH_CHECK" disabling to suppress:
	#   warning: Insecure world writable dir
	&& { \
	echo '#define ENABLE_PATH_CHECK 0'; \
	echo; \
	cat file.c; \
	} > file.c.new \
	&& mv file.c.new file.c \
	\
	&& autoconf \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
	--build="$gnuArch" \
	--disable-install-doc \
	--enable-shared \
	&& make -j "$(nproc)" \
	&& make install \
	\
	&& apt-get purge -y --auto-remove $buildDeps \
	&& cd / \
	&& rm -r /usr/src/ruby \
	\
	&& gem update --system "$RUBYGEMS_VERSION"

ENV BUNDLER_VERSION 1.15.2

RUN gem install bundler --version "$BUNDLER_VERSION"

# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
	BUNDLE_BIN="$GEM_HOME/bin" \
	BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
	&& chmod 777 "$GEM_HOME" "$BUNDLE_BIN"


#
# Install Java
#

RUN apt-get update && apt-get install -y openjdk-7-jre

#
# https://github.com/broadinstitute/docker-terraform/blob/master/Dockerfile
#

ENV TERRAFORM_VERSION=0.11.9

RUN apt-get update && apt-get install -y unzip jq

RUN cd /tmp && \
	wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
	unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/bin && \
	rm -rf /tmp/*

# 
# Install Heroku
# 
RUN wget -qO- https://cli-assets.heroku.com/install-ubuntu.sh | sh

# 
# Install Pivotal Tracker script
# 
RUN gem install tracker-git

#
# Install binaries to support puppeteer (it's possible that not all are necessary, but 
# I don't know which those would be)
#
RUN apt-get update && apt-get install -y libxss1 libappindicator1 libasound2 libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 gconf-service lsb-release wget xdg-utils fonts-liberation

