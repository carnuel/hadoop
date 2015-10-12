FROM carnuel/ubuntu-java-ssh:v2
MAINTAINER carnuel

USER root

# Download hadoop 2.7.1
RUN curl -s http://www.eu.apache.org/dist/hadoop/common/hadoop-2.7.1/hadoop-2.7.1.tar.gz | tar -xz -C /usr/local/
RUN cd /usr/local && ln -s ./hadoop-2.7.1 hadoop

# Configure environment variables
ENV HADOOP_PREFIX /usr/local/hadoop
ENV PATH $PATH:/usr/local/hadoop/bin/
ENV HADOOP_HOME $HADOOP_PREFIX
ENV HADOOP_COMMON_HOME $HADOOP_PREFIX
ENV HADOOP_CONF_DIR $HADOOP_PREFIX/etc/hadoop
ENV HADOOP_HDFS_HOME $HADOOP_PREFIX
ENV HADOOP_MAPRED_HOME $HADOOP_PREFIX
ENV HADOOP_YARN_HOME $HADOOP_PREFIX
RUN sed -i '/^export JAVA_HOME/ s:.*:export JAVA_HOME=/usr/java/default\nexport HADOOP_PREFIX=/usr/local/hadoop\nexport HADOOP_HOME=/usr/local/hadoop\n:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
RUN sed -i '/^export HADOOP_CONF_DIR/ s:.*:export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop/:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

# Add XML-sites and templates
ADD core-site.xml.template $HADOOP_PREFIX/etc/hadoop/core-site.xml.template
ADD hdfs-site.xml $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml
ADD yarn-site.xml.template $HADOOP_PREFIX/etc/hadoop/yarn-site.xml.template
ADD mapred-site.xml.template $HADOOP_PREFIX/etc/hadoop/mapred-site.xml.template

# SSH config
ADD ssh_config /root/.ssh/config
RUN chmod 600 /root/.ssh/config
RUN chown root:root /root/.ssh/config

# Add entrypoint bootstrap.sh
ADD bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh
RUN chmod 700 /etc/bootstrap.sh
ENV BOOTSTRAP /etc/bootstrap.sh

CMD ["/etc/bootstrap.sh", "-d"]

EXPOSE 50020 50090 50070 50010 50075 8031 8032 8033 8040 8042 49707 22 8088 8030 50666 49911 56613 38609 34608

