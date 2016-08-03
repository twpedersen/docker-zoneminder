#name of container: docker-zoneminder
#versison of container: 0.5.7
FROM quantumobject/docker-baseimage:15.10
MAINTAINER Angel Rodriguez  "angel@quantumobject.com"

#add repository and update the container
#Installation of nesesary package/software for this containers...
RUN echo "deb http://archive.ubuntu.com/ubuntu `cat /etc/container_environment/DISTRIB_CODENAME`-backports main restricted universe" >> /etc/apt/sources.list  \
      && echo "deb http://ppa.launchpad.net/iconnor/zoneminder-master/ubuntu `cat /etc/container_environment/DISTRIB_CODENAME` main" >> /etc/apt/sources.list  \
      && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 776FFB04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y -q mysql-server  \
                                        libvlc-dev  \
                                        libvlccore-dev\
                                        libapache2-mod-perl2 \
                                        vlc \
                                        ntp \
                                        dialog \
                                        ntpdate \
                    && apt-get clean \
                    && rm -rf /tmp/* /var/tmp/*  \
                    && rm -rf /var/lib/apt/lists/*

#remove temporal to fix some other problem and check others .. 
#install ffmpeg
COPY ffmpeg.sh /tmp/ffmpeg.sh
RUN chmod +x /tmp/ffmpeg.sh ; sync \
    && /bin/bash -c /tmp/ffmpeg.sh

# to add mysqld deamon to runit
# need to remove STRICT_TRANS_TABLES from sql_mode or zm crashes
RUN sed -i "s/^sql_mode=.*/sql_mode=NO_ENGINE_SUBSTITUTION/g" /usr/my.cnf
RUN mkdir -p /etc/service/mysqld /var/log/mysqld ; sync 
RUN mkdir /etc/service/mysqld/log
COPY mysqld.sh /etc/service/mysqld/run
COPY mysqld-log.sh /etc/service/mysqld/log/run
RUN chmod +x /etc/service/mysqld/run /etc/service/mysqld/log/run \
    && cp /var/log/cron/config /var/log/mysqld/ \
    && chown -R mysql /var/log/mysqld

# to add apache2 deamon to runit
RUN mkdir -p /etc/service/apache2  /var/log/apache2 ; sync 
RUN mkdir /etc/service/apache2/log
COPY apache2.sh /etc/service/apache2/run
COPY apache2-log.sh /etc/service/apache2/log/run
RUN chmod +x /etc/service/apache2/run /etc/service/apache2/log/run \
    && cp /var/log/cron/config /var/log/apache2/ \
    && chown -R www-data /var/log/apache2

# to add zm deamon to runit
RUN mkdir -p /var/log/zm ; sync 
COPY zm.sh /sbin/zm.sh
RUN chmod +x /sbin/zm.sh
    
# to add ntp deamon to runit
RUN mkdir -p /etc/service/ntp  /var/log/ntp ; sync 
RUN mkdir /etc/service/ntp/log
COPY ntp.sh /etc/service/ntp/run
COPY ntp-log.sh /etc/service/ntp/log/run
RUN chmod +x /etc/service/ntp/run /etc/service/ntp/log/run \
    && cp /var/log/cron/config /var/log/ntp/ \
    && chown -R nobody /var/log/ntp

##startup scripts  
#Pre-config scrip that maybe need to be run one time only when the container run the first time .. using a flag to don't 
#run it again ... use for conf for service ... when run the first time ...
RUN mkdir -p /etc/my_init.d
COPY startup.sh /etc/my_init.d/startup.sh
RUN chmod +x /etc/my_init.d/startup.sh

#pre-config scritp for different service that need to be run when container image is create 
#maybe include additional software that need to be installed ... with some service running ... like example mysqld
COPY pre-conf.sh /sbin/pre-conf
RUN chmod +x /sbin/pre-conf ; sync \
    && /bin/bash -c /sbin/pre-conf \
    && rm /sbin/pre-conf

##scritp that can be running from the outside using docker-bash tool ...
## for example to create backup for database with convitation of VOLUME   dockers-bash container_ID backup_mysql
COPY backup.sh /sbin/backup
RUN chmod +x /sbin/backup
VOLUME /var/backups

RUN cd /usr/src \
    && wget http://www.andywilcock.com/code/cambozola/cambozola-latest.tar.gz \
    && tar -xzvf /usr/src/cambozola-latest.tar.gz \
    && mv cambozola-0.936/dist/cambozola.jar /usr/share/zoneminder/www  \
    && rm /usr/src/cambozola-latest.tar.gz \
    && rm -R /usr/src/cambozola-0.936
    
RUN echo "!/bin/sh ntpdate 0.ubuntu.pool.ntp.org" >> /etc/cron.daily/ntpdate \
    && chmod 750 /etc/cron.daily/ntpdate


VOLUME /var/lib/mysql /var/cache/zoneminder
# to allow access from outside of the container  to the container service
# at that ports need to allow access from firewall if need to access it outside of the server. 
EXPOSE 80

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]
