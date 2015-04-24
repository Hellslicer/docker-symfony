FROM debian:wheezy

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/* && curl -O http://www.dotdeb.org/dotdeb.gpg && apt-key add dotdeb.gpg
RUN echo "deb http://packages.dotdeb.org wheezy all" >> /etc/apt/sources.list
RUN echo "deb-src http://packages.dotdeb.org wheezy all" >> /etc/apt/sources.list
RUN echo "deb http://packages.dotdeb.org wheezy-php56 all" >> /etc/apt/sources.list
RUN echo "deb-src http://packages.dotdeb.org wheezy-php56 all" >> /etc/apt/sources.list

RUN apt-get update && apt-get install -y git nginx php5-fpm php5-mysqlnd php5-cli mysql-server supervisor php5-dev php-pear && rm -rf /var/lib/apt/lists/*

# Temporary installation of Xdebug
RUN pecl install xdebug
RUN echo zend_extension=/usr/lib/php5/20131226/xdebug.so > /etc/php5/fpm/conf.d/xdebug.ini
RUN echo xdebug.default_enable = 1 >> /etc/php5/fpm/conf.d/xdebug.ini
RUN echo xdebug.remote_enable = 1 >> /etc/php5/fpm/conf.d/xdebug.ini
RUN echo xdebug.remote_port = 9000 >> /etc/php5/fpm/conf.d/xdebug.ini
RUN echo xdebug.remote_connect_back=1 >> /etc/php5/fpm/conf.d/xdebug.ini
RUN echo xdebug.remote_handler=dbgp >> /etc/php5/fpm/conf.d/xdebug.ini
RUN echo xdebug.remote_log="/var/log/xdebug.log" >> /etc/php5/fpm/conf.d/xdebug.ini
RUN echo xdebug.remote_host=0.0.0.0 >> /etc/php5/fpm/conf.d/xdebug.ini
RUN cp /etc/php5/fpm/conf.d/xdebug.ini /etc/php5/cli/conf.d/xdebug.ini

RUN export VERSION=`php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;"` \
    && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/amd64/${VERSION} \
    && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp \
    && mv /tmp/blackfire-*.so `php -r "echo ini_get('extension_dir');"`/blackfire.so \
    && echo "extension=blackfire.so\nblackfire.agent_socket=\${BLACKFIRE_PORT}" > /etc/php5/fpm/conf.d/blackfire.ini

RUN sed -e 's/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = E_ALL/' -i /etc/php5/cli/php.ini
RUN sed -e 's/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = E_ALL/' -i /etc/php5/fpm/php.ini
RUN sed -e 's/;date\.timezone =/date.timezone = \"Europe\/Paris\"/' -i /etc/php5/cli/php.ini
RUN sed -e 's/;date\.timezone =/date.timezone = \"Europe\/Paris\"/' -i /etc/php5/fpm/php.ini
RUN sed -e 's/;daemonize = yes/daemonize = no/' -i /etc/php5/fpm/php-fpm.conf
RUN sed -e 's/;listen\.owner/listen.owner/' -i /etc/php5/fpm/pool.d/www.conf
RUN sed -e 's/;listen\.group/listen.group/' -i /etc/php5/fpm/pool.d/www.conf
RUN sed -e 's/pm\.max_children = 5/pm.max_children = 16/' -i /etc/php5/fpm/pool.d/www.conf
RUN sed -e 's/pm\.start_servers = 2/pm.start_servers = 6/' -i /etc/php5/fpm/pool.d/www.conf
RUN sed -e 's/pm\.min_spare_servers = 1/pm.min_spare_servers = 3/' -i /etc/php5/fpm/pool.d/www.conf
RUN sed -e 's/pm\.max_spare_servers = 3/pm.max_spare_servers = 11/' -i /etc/php5/fpm/pool.d/www.conf
RUN sed -e 's/;pm\.max_requests = 500/pm.max_requests = 500/' -i /etc/php5/fpm/pool.d/www.conf
RUN echo "memory_limit=1024M" > /etc/php5/cli/conf.d/memory-limit.ini
RUN sed -e 's/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' -i /etc/mysql/my.cnf
RUN sed -e 's/:33:33:/:1000:1000:/' -i /etc/passwd
RUN echo "\ndaemon off;" >> /etc/nginx/nginx.conf

ENV COMPOSER_HOME /root/composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN curl -O https://phar.phpunit.de/phpunit.phar && chmod +x phpunit.phar && mv phpunit.phar /usr/local/bin/phpunit

RUN echo '#!/bin/bash' > /usr/local/bin/dev && echo 'php /srv/app/console --env=dev $@' >> /usr/local/bin/dev && chmod +x /usr/local/bin/dev
RUN echo '#!/bin/bash' > /usr/local/bin/prod && echo 'php /srv/app/console --env=prod $@' >> /usr/local/bin/prod && chmod +x /usr/local/bin/prod

RUN echo 'shell /bin/bash' > ~/.screenrc

ADD vhost.conf /etc/nginx/sites-available/default
ADD supervisor.conf /etc/supervisor/conf.d/supervisor.conf
ADD mysql.sh /usr/local/bin/mysql.sh
RUN chmod +x /usr/local/bin/mysql.sh
ADD init.sh /init.sh

EXPOSE 80 3306

VOLUME ["/srv"]
WORKDIR /srv

CMD ["/usr/bin/supervisord"]
