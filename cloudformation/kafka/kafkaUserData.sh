#!/bin/bash
# Install Java
yum -y install java

# Get the Kafka binaries, extract to /opt
mkdir /opt/kafka
cd /opt/kafka
wget http://apache.mirror.anlx.net/kafka/2.6.0/kafka_2.13-2.6.0.tgz
tar -xvzf kafka_2.13-2.6.0.tgz
mv kafka_2.13-2.6.0/* .
rmdir /opt/kafka/kafka_2.13-2.6.0

# Create the services
cat > /lib/systemd/system/zookeeper.service << EOL
[Unit]
Requires=network.target remote-fs.target
After=network.target remote-fs.target

[Service]
Type=simple
User=root
ExecStart=/opt/kafka/bin/zookeeper-server-start.sh /opt/kafka/config/zookeeper.properties
ExecStop=/opt/kafka/bin/zookeeper-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOL
cat > /lib/systemd/system/kafka.service << EOL
[Unit]
Requires=network.target remote-fs.target zookeeper.service
After=network.target remote-fs.target zookeeper.service

[Service]
Type=simple
User=root
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOL

# Get the Kafka hostname so it can be added to the advertised listeners
my_ip=$(curl http://169.254.169.254/latest/meta-data/public-hostname)

# Configure Kafka
sed -i 's/#listeners=PLAINTEXT:\/\/:9092/listeners=PLAINTEXT:\/\/:9092/g' /opt/kafka/config/server.properties
sed -i 's/log.dirs=\/tmp\/kafka-logs/log.dirs=\/var\/log\/kafka-logs/g' /opt/kafka/config/server.properties
sed -i "s/#advertised.listeners=PLAINTEXT:\/\/your.host.name:9092/advertised.listeners=PLAINTEXT:\/\/"$my_ip":9092/g" /opt/kafka/config/server.properties

# Reload daemons
systemctl daemon-reload
# Create the logs directory
mkdir -p /var/log/kafka-logs
# Start the services
sudo systemctl start zookeeper.service
sudo systemctl start kafka.service
#Enable at startup
systemctl enable zookeeper.service
systemctl enable kafka.service
# Create topics
bin/kafka-topics.sh --create --topic twitter --bootstrap-server localhost:9092
bin/kafka-topics.sh --create --topic gdelt --bootstrap-server localhost:9092