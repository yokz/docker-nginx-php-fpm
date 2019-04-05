FROM php:7.3-fpm

ENV PHPREDIS_VERSION 4.3.0

RUN apt-get update && apt-get install -y curl gnupg2 ca-certificates lsb-release \
    && echo "deb http://nginx.org/packages/debian `lsb_release -cs` nginx" \
	    | tee /etc/apt/sources.list.d/nginx.list \
	&& curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add - \
    && curl -sL https://deb.nodesource.com/setup_10.x | bash - \
	&& apt-get update && apt-get install -y --no-install-recommends \
	openssh-client \
    wget \
    git \
    dialog \
    musl-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libpng-dev \
    libxslt-dev \
    libffi-dev \
    libicu-dev \
    libtidy-dev \
    libzip-dev \
    supervisor \
    nginx \
    nodejs \
    && docker-php-ext-install \
        pdo_mysql \
        mysqli \
        gd \
        exif \
        intl \
        xsl \
        json \
        soap \
        dom \
        zip \
        bcmath \
        opcache \
        tidy \
    && docker-php-source delete \
    && mkdir /etc/nginx/sites-enabled

####################
# Install Composer #
####################
RUN ( \
        EXPECTED_COMPOSER_SIGNATURE=$(wget -q -O - https://composer.github.io/installer.sig) && \
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
        php -r "if (hash_file('SHA384', 'composer-setup.php') === '${EXPECTED_COMPOSER_SIGNATURE}') { echo 'Composer.phar Installer verified'; } else { echo 'Composer.phar Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
        php composer-setup.php --install-dir=/usr/bin --filename=composer && \
        php -r "unlink('composer-setup.php');" \
    )

#############
# PHP Redis #
#############
RUN ( \
        curl -L -o /tmp/redis.tar.gz "http://github.com/phpredis/phpredis/archive/${PHPREDIS_VERSION}.tar.gz" \
        && mkdir -p /tmp/redis \
        && tar -C /tmp/redis -zxvf /tmp/redis.tar.gz --strip 1 \
        && cd /tmp/redis \
        && ( \
        	phpize \
        	&& ./configure \
        	&& make \
        	&& make install \
        ) \
        && docker-php-ext-enable redis \
        && rm /tmp/redis.tar.gz \
        && rm -r /tmp/redis \
    )

#####################
# PHP Configuration #
#####################
COPY ./config/php/php-fpm.conf /usr/local/etc/
COPY ./config/php/php-fpm.d/* /usr/local/etc/php-fpm.d/
COPY ./config/php/php/conf.d/* /usr/local/etc/php/conf.d/

#######################
# NGINX Configuration #
#######################
COPY ./config/nginx/nginx.conf /etc/nginx/
COPY ./config/nginx/conf.d/* /etc/nginx/conf.d/

############################
# Supervisor Configuration #
############################
COPY ./config/supervisor/supervisord.conf /etc/supervisor
COPY ./config/supervisor/conf.d/* /etc/supervisor/conf.d/

EXPOSE 80 443

CMD supervisord -n -c /etc/supervisor/supervisord.conf
