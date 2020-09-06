import json
from tweepy.streaming import StreamListener
from tweepy import OAuthHandler
from tweepy import Stream
from textblob import TextBlob
from kafka import KafkaProducer
from kafka.errors import KafkaError

# import twitter keys and tokens
from config import *

# create instance of kafka producer
host = 'ec2-35-179-91-121.eu-west-2.compute.amazonaws.com:9092'
producer = KafkaProducer(bootstrap_servers=[host], value_serializer=lambda m: json.dumps(m).encode('ascii'))

class TweetStreamListener(StreamListener):

    # on success
    def on_data(self, data):

        # decode json
        dict_data = json.loads(data)

        # Try to exlude any RTs
        if ("retweeted_status" not in dict_data) and ('RT @' not in dict_data["text"]):

            # pass tweet into TextBlob
            tweet = TextBlob(dict_data["text"])

            sentiment = 'neutral'
            # determine if sentiment is positive, negative, or neutral
            if tweet.sentiment.polarity < 0:
                sentiment = "negative"
            elif tweet.sentiment.polarity == 0:
                sentiment = "neutral"
            else:
                sentiment = "positive"

            dict_data['sentiment'] = sentiment
            # Send to Kafka
            producer.send('twitter', dict_data)    

    # on failure
    def on_error(self, status):
        print(status)

if __name__ == '__main__':

    # create instance of the tweepy tweet stream listener
    listener = TweetStreamListener()

    # set twitter keys/tokens
    auth = OAuthHandler(consumer_key, consumer_secret)
    auth.set_access_token(access_token, access_token_secret)

    # create instance of the tweepy stream
    stream = Stream(auth, listener)

    # search twitter for "congress" keyword
    stream.filter(locations=[-14.872742,48.239080,11.900940,56.126993,-4.921875,4.039618,102.172852,48.545705])