#!/usr/bin/env bash
# Copyright 2014 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS-IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Misc configurations for components not installed elsewhere.
# Not necessarily CDH specific.

# Use FQDNs
grep ${HOSTNAME} -lR ${HADOOP_CONF_DIR} \
  | xargs -r sed -i "s/${HOSTNAME}/$(hostname --fqdn)/g"

# Configure Hive Metastore
if dpkg -s hive-metastore > /dev/null; then
  # Configure Hive metastorea
  bdconfig set_property \
      --configuration_file /etc/hive/conf/hive-site.xml \
      --name 'hive.metastore.uris' \
      --value "thrift://$(hostname --fqdn):9083" \
      --clobber
fi

# Configure Impala 
if dpkg -s impala > /dev/null; then
  cp ${HADOOP_CONF_DIR}/core-site.xml /etc/impala/conf

  # Configure Hive metastore
  cp cdh-hive-site-template.xml /etc/impala/conf/hive-site.xml
  bdconfig set_property \
      --configuration_file /etc/impala/conf/hive-site.xml \
      --name 'hive.metastore.uris' \
      --value "thrift://${MASTER_HOSTNAME}:9083" \
      --clobber

  # Configure short-circuit reads
  bdconfig set_property \
      --configuration_file ${HADOOP_CONF_DIR}/hdfs-site.xml \
      --name 'dfs.client.read.shortcircuit' \
      --value "true" \
      --clobber

  bdconfig set_property \
      --configuration_file ${HADOOP_CONF_DIR}/hdfs-site.xml \
      --name 'dfs.domain.socket.path' \
      --value "/var/run/hadoop-hdfs/dn" \
      --clobber

  bdconfig set_property \
      --configuration_file ${HADOOP_CONF_DIR}/hdfs-site.xml \
      --name 'dfs.client.file-block-storage-locations.timeout.millis' \
      --value "10000" \
      --clobber

  bdconfig set_property \
      --configuration_file ${HADOOP_CONF_DIR}/hdfs-site.xml \
      --name 'dfs.datanode.hdfs-blocks-metadata.enabled' \
      --value "true" \
      --clobber
  cp ${HADOOP_CONF_DIR}/hdfs-site.xml /etc/impala/conf

cat << EOF > /etc/impala/conf/hbase-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>hbase.client.connection.impl</name>
    <value>com.google.cloud.bigtable.hbase1_0.BigtableConnection</value>
  </property>
  <property>
    <name>google.bigtable.cluster.name</name>
    <value>impala</value>
  </property>
  <property>
    <name>google.bigtable.project.id</name>
    <value>graphite-impala-demo</value>
  </property>
  <property>
    <name>google.bigtable.zone.name</name>
    <value>us-central1-c</value>
  </property>
</configuration>
EOF
fi

# Configure Hue
if dpkg -s hue > /dev/null; then
  # Replace localhost with hostname.
  sed -i "s/#*\([^#]*=.*\)localhost/\1$(hostname --fqdn)/" /etc/hue/conf/hue.ini
fi

# Configure Oozie
if dpkg -s oozie > /dev/null; then
  sudo -u oozie /usr/lib/oozie/bin/ooziedb.sh create -run

  # Try to enable gs:// paths
  bdconfig set_property \
      --configuration_file /etc/oozie/conf/oozie-site.xml \
      --name 'oozie.service.HadoopAccessorService.supported.filesystems' \
      --value 'hdfs,gs,webhdfs,hftp' \
      --clobber
fi

# Enable WebHDFS
bdconfig set_property \
    --configuration_file ${HADOOP_CONF_DIR}/hdfs-site.xml \
    --name 'dfs.webhdfs.enabled' \
    --value true \
    --clobber

# Enable Hue / Oozie impersonation
bdconfig merge_configurations \
    --configuration_file ${HADOOP_CONF_DIR}/core-site.xml \
    --source_configuration_file cdh-core-template.xml \
    --resolve_environment_variables \
    --clobber
