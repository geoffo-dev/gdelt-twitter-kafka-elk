# gdelt-twitter-kafka-elk
These are the source files used for the project discussed on the medium post

xxx

# CloudFormation Template
The complete CloudFormation templace is contained within the CloudFormation Folder. The sub folders contained within this contain the UserData scripts for each of the instances.

Also included in the Kafka test script from Cloudera for troubleshooting Kafka connection issues.

# GDELT Streamer
Contained within the GDELT data folder. You will need to edit *gdeltgrabber.py* to include the name of the Kafka host - you should be able to find after you create the instance

```python
# create instance of kafka producer
host = 'xxxxx:9092'
```

The GDELT streamer does pull all of the GDELT sources, but only uses the events dataset for sending to Kafka currently. 

## Based on
This streamer is based on the following two projects:

* https://github.com/panchicore/es-gdelt
* https://github.com/shaialon/elasticsearch-gdelt 

Thank you!

# Twitter Streamer
Similar to the GDELT Streamer you will need to change the host to the hostname of your newly created Kafka instance

```python
# create instance of kafka producer
host = 'xxxxx:9092'
```

You will also need to adjust the *config.py* file to include your API keys from twitter.

## Based on
This streamer is based on the following blog:

* https://realpython.com/twitter-sentiment-python-docker-elasticsearch-kibana/ 

Thank you!