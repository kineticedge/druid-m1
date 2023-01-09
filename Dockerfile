FROM openjdk:11-jdk-slim as builder

RUN \
	export DEBIAN_FRONTEND=noninteractive \
	&& apt-get -qq update \
	&& apt-get -qq -y install --no-install-recommends python3 python3-yaml

#
# Install Maven binary
# (so optional extensions can be added through the build-in package manager)
#
ADD http://archive.apache.org/dist/maven/maven-3/3.8.1/binaries/apache-maven-3.8.1-bin.tar.gz /tmp/apache-maven-3.8.1-bin.tar.gz
RUN \
	tar -zxf /tmp/apache-maven-3.8.1-bin.tar.gz -C /opt/; \
	mv /opt/apache-maven-3.8.1 /opt/maven; \
	rm /tmp/apache-maven-3.8.1-bin.tar.gz

ENV MVN_HOME=/opt/maven
ENV PATH=$PATH:$MVN_HOME/bin

#
# Install Apache Druid binary and docker entrypoint from specified release.
#
ARG DRUID_VERSION=25.0.0
ADD https://dlcdn.apache.org/druid/${DRUID_VERSION}/apache-druid-${DRUID_VERSION}-bin.tar.gz /tmp
ADD https://raw.githubusercontent.com/apache/druid/${DRUID_VERSION}/distribution/docker/druid.sh /druid.sh
RUN \
	tar -zxf /tmp/apache-druid-${DRUID_VERSION}-bin.tar.gz -C /opt; \
	mv /opt/apache-druid-${DRUID_VERSION} /opt/druid; \
	rm /tmp/apache-druid-${DRUID_VERSION}-bin.tar.gz

RUN \
	java -cp "/opt/druid/lib/*" \
		-Ddruid.extensions.directory="/opt/druid/extensions/" \
		-Ddruid.extensions.hadoopDependenciesDir="/opt/druid/hadoop-dependencies/" \
		org.apache.druid.cli.Main tools pull-deps --no-default-hadoop \
		-c "org.apache.druid.extensions.contrib:kafka-emitter"

                #-c org.apache.druid.extensions.contrib:druid-google-extensions \
                #-c org.apache.druid.extensions.contrib:ambari-metrics-emitter \
                #-c org.apache.druid.extensions.contrib:druid-cassandra-storage \
                #-c org.apache.druid.extensions.contrib:druid-cloudfiles-extensions \
                #-c org.apache.druid.extensions.contrib:druid-distinctcount \
                #-c org.apache.druid.extensions.contrib:druid-rocketmq \
                #-c org.apache.druid.extensions.contrib:graphite-emitter \
                #-c org.apache.druid.extensions.contrib:druid-influx-extensions \
                #-c org.apache.druid.extensions.contrib:materialized-view-maintenance \
                #-c org.apache.druid.extensions.contrib:materialized-view-selection \
                #-c org.apache.druid.extensions.contrib:druid-opentsdb-emitter \
                #-c org.apache.druid.extensions.contrib:druid-orc-extensions \
                #-c org.apache.druid.extensions.contrib:druid-rabbitmq \
                #-c org.apache.druid.extensions.contrib:druid-redis-cache \
                #-c org.apache.druid.extensions.contrib:sqlserver-metadata-storage \
                #-c org.apache.druid.extensions.contrib:statsd-emitter \
                #-c org.apache.druid.extensions.contrib:druid-thrift-extensions \
                #-c org.apache.druid.extensions.contrib:druid-time-min-max \
                #-c org.apache.druid.extensions.contrib:druid-virtual-columns

#
# Use busybox as a means to add basic linux commands to the jre-slim container
#
#FROM arm64v8/busybox:latest as busybox
FROM busybox:latest as busybox

#FROM openjdk:8u332-jre-buster
#FROM openjdk:11.0.15-jre-buster
FROM openjdk:11-jre-slim

LABEL maintainer="..."

COPY --from=busybox /bin/busybox /busybox/busybox

RUN \
	["/busybox/busybox", "--install", "/bin"]

RUN \
	addgroup --system -gid 1000 druid \
	&& adduser --system --uid 1000 --gid 1000 --home /opt/druid --shell /bin/sh druid

COPY --chown=druid:druid --from=builder /opt /opt
COPY --chown=druid:druid --from=builder /druid.sh /druid.sh

RUN \
	mkdir /opt/druid/var /opt/shared \
	&& chown druid:druid /opt/druid/var /opt/shared /druid.sh \
	&& chmod 775 /opt/druid/var /opt/shared /druid.sh 

USER druid
VOLUME /opt/druid/var
WORKDIR /opt/druid
ENTRYPOINT ["/druid.sh"]
