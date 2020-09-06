#!/bin/bash
# Install Elasticsearch
# https://www.elastic.co/guide/en/elasticsearch/reference/current/rpm.html
# Get ElasticSearch
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
touch /etc/yum.repos.d/elasticsearch.repo
# Create the repo link
cat > /etc/yum.repos.d/elasticsearch.repo << EOL
[elasticsearch]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOL
# Now install Elasticsearch
yum -y install --enablerepo=elasticsearch elasticsearch 
# Configure /etc/elasticsearch/
sed -i 's/#network.host: 192.168.0.1/network.host: 0.0.0.0/g' /etc/elasticsearch/elasticsearch.yml
sed -i 's/#http.port: 9200/http.port: 9200/g' /etc/elasticsearch/elasticsearch.yml
sed -i 's/#discovery.seed_hosts: \[\"host1\", \"host2\"\]/discovery.seed_hosts: \[\"localhost\", \"\[::1\]\"\]/g' /etc/elasticsearch/elasticsearch.yml
sed -i 's/#node.name: node-1/node.name: node-1/g' /etc/elasticsearch/elasticsearch.yml
sed -i 's/#cluster.initial_master_nodes: \[\"node-1\", \"node-2\"\]/cluster.initial_master_nodes: \[\"node-1\"\]/g' /etc/elasticsearch/elasticsearch.yml #Not sure this is needed for single node clusters
# Start Elasticsearch
systemctl enable elasticsearch
service elasticsearch start
# Check Health
curl -X GET "localhost:9200/_cat/health?v&pretty"

# Install Kibana
# https://www.elastic.co/guide/en/kibana/current/rpm.html 
# Create the repo link
cat > /etc/yum.repos.d/kibana.repo << EOL
[kibana-7.x]
name=Kibana repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOL
# Install Kibana
yum -y install kibana
systemctl enable kibana
# Set Config
sed -i 's/#server.host: \"localhost\"/server.host: \"0.0.0.0\"/g' /etc/kibana/kibana.yml
sed -i 's/#elasticsearch.hosts: \[\"http:\/\/localhost:9200\"\]/elasticsearch.hosts: \[\"http:\/\/127.0.0.1:9200\"\]/g' /etc/kibana/kibana.yml
sed -i 's/#logging.dest: stdout/logging.dest: \/var\/log\/kibana\/kibana.log/g' /etc/kibana/kibana.yml
# Start Kibana
service kibana start

# Install logstash.
cat > /etc/yum.repos.d/logstash.repo << EOL
[logstash-7.x]
name=Elastic repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOL
# Install logstash - Need to install java to get $JAVA_HOME and create startup scripts
yum -y install logstash java
./usr/share/logstash/bin/system-install
systemctl enable logstash
# Configure logstash
cat > /etc/logstash/conf.d/logstash-twitter.conf << EOL
input { 
    kafka { 
            bootstrap_servers => "${KafkaIP}:9092" 
            topics => ["twitter"] 
            codec => "json"
    } 
} 
output { 
    elasticsearch {
            hosts => ["localhost:9200"]
            index => 'twitter'
    }
    s3{
        region => "${AWS::Region}"               
        bucket => "${S3BucketName}"             
        size_file => 1048576
        prefix => "twitter/"                       
        time_file => 5                          
        codec => "json"                        
        canned_acl => "private"              
    }
} 
EOL
cat > /etc/logstash/conf.d/logstash-gdelt.conf << EOL
input { 
    kafka { 
            bootstrap_servers => "${KafkaIP}:9092" 
            topics => ["gdelt"] 
            codec => "json"
    } 
} 
output { 
    elasticsearch {
            hosts => ["localhost:9200"]
            index => 'gdelt'
    }
    s3{
        region => "${AWS::Region}"               
        bucket => "${S3BucketName}"             
        size_file => 1048576
        prefix => "gdelt/"                       
        time_file => 5                          
        codec => "json"                        
        canned_acl => "private"              
    }
} 
EOL

# Setup the pipelines
cat > /etc/logstash/pipelines.yml  << EOL
- pipeline.id: twitter
  path.config: "/etc/logstash/conf.d/logstash-twitter.conf"
- pipeline.id: gdelt
  path.config: "/etc/logstash/conf.d/logstash-gdelt.conf"
EOL

# Start logstash
service logstash start