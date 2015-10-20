FROM carnuel/ubuntu:latest
MAINTAINER carnuel
USER root

# Download hadoop 2.7.1
RUN curl -s http://www.eu.apache.org/dist/hadoop/common/hadoop-2.7.1/hadoop-2.7.1.tar.gz | tar -xz -C /usr/local/ && \
	cd /usr/local && ln -s ./hadoop-2.7.1 hadoop

# Set environment variables
ENV HADOOP_PREFIX /usr/local/hadoop
ENV PATH $PATH:/usr/local/hadoop/bin/
ENV HADOOP_HOME $HADOOP_PREFIX
ENV HADOOP_COMMON_HOME $HADOOP_PREFIX
ENV HADOOP_CONF_DIR $HADOOP_PREFIX/etc/hadoop
ENV HADOOP_HDFS_HOME $HADOOP_PREFIX
ENV HADOOP_MAPRED_HOME $HADOOP_PREFIX
ENV HADOOP_YARN_HOME $HADOOP_PREFIX
RUN sed -i '/^export JAVA_HOME/ s:.*:export JAVA_HOME=/usr/java/default\nexport HADOOP_PREFIX=/usr/local/hadoop\nexport HADOOP_HOME=/usr/local/hadoop\n:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh \
	&& sed -i '/^export HADOOP_CONF_DIR/ s:.*:export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop/:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

# Copy local files
#COPY core-site.xml.template $HADOOP_PREFIX/etc/hadoop/core-site.xml.template
#COPY hdfs-site.xml $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml
#COPY yarn-site.xml.template $HADOOP_PREFIX/etc/hadoop/yarn-site.xml.template
#COPY mapred-site.xml.template $HADOOP_PREFIX/etc/hadoop/mapred-site.xml.template
#COPY bootstrap.sh /etc/bootstrap.sh

# Set permissions
#RUN chown root:root /etc/bootstrap.sh && chmod 700 /etc/bootstrap.sh

# Set environment variable
ENV BOOTSTRAP /mnt/bootstrap.sh

ENTRYPOINT ["/mnt/bootstrap.sh"]
CMD ["-d"]
