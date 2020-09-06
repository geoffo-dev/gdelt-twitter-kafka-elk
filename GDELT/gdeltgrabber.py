import os
import zipfile
import requests
import sys
import datetime
import csv
import json
from kafka import KafkaProducer
from kafka.errors import KafkaError
from gdeltconfig import *

# create instance of kafka producer
host = 'ec2-18-133-225-139.eu-west-2.compute.amazonaws.com:9092'
producer = KafkaProducer(bootstrap_servers=[host], value_serializer=lambda m: json.dumps(m).encode('ascii'))

def download_file(url):
    """

    :param url:
    :return:
    """
    print('downloading:', url)
    local_filename = url.split('/')[-1]
    #local_filename = os.path.join("./", local_filename)
    # NOTE the stream=True parameter
    r = requests.get(url, stream=True)
    if not r.ok:
        print("request returned with code {}".format(r.status_code))
        return None
    with open(local_filename, 'wb') as f:
        for chunk in r.iter_content(chunk_size=1024):
            if chunk:  # filter out keep-alive new chunks
                f.write(chunk)
    return local_filename


def unzip(path):
    print('unzipping:', path)
    zip_ref = zipfile.ZipFile(path, 'r')
    zip_ref.extractall()
    zip_ref.close()

def process_events(filename):

    with open(filename, newline = '') as events:                                                                                          
    	event_reader = csv.DictReader(events, delimiter='\t', fieldnames=eventtitles)
        # Complete the conversion of the geodata to match geopoint ES specification
    	for event in event_reader:
            # Need to check if the fields are populated - float conversions are required
            if event['ActionGeo_Long'] != '' :
                event['ActionGeo_Location']= [ float(event['ActionGeo_Long']), float(event['ActionGeo_Lat']) ]
            if event['Actor1Geo_Lat'] != '' :
                event['Actor1Geo_Location']= [ float(event['Actor1Geo_Long']), float(event['Actor1Geo_Lat']) ]
            if event['Actor2Geo_Lat'] != '' :
                event['Actor2Geo_Location']= [ float(event['Actor2Geo_Long']), float(event['Actor2Geo_Lat']) ]

            # Convert the various codes into text so they can be properly visualised
            if event['EventCode'] != '':
                event['EventCode'] = eventcodes[event['EventCode']]
            if event['EventBaseCode'] != '':
                event['EventBaseCode'] = eventcodes[event['EventBaseCode']]
            if event['EventRootCode'] != '':
                event['EventRootCode'] = eventrootcodes[event['EventRootCode']]
            if event['QuadClass'] != '':
                event['QuadClass'] = quadclassnames[event['QuadClass']]
            if event['IsRootEvent'] != '':
                event['IsRootEvent'] = rootEventNames[event['IsRootEvent']]

            producer.send('gdelt', event) 


def get(_from_date=None):
    """

    :param _from_date:
    :return
    """

    feeds = [
        "http://data.gdeltproject.org/gdeltv2/lastupdate.txt",
        "http://data.gdeltproject.org/gdeltv2/lastupdate-translation.txt"
    ]

    for feed in feeds:
        if not _from_date:
            res = requests.get(feed)
            url = None
            gkg_url = None
            mentions_url = None
            resStr = str(res.content)

            for line in resStr.split("\\n"):
                if not line:
                    continue

                if line.count(".export.CSV.zip") > 0:
                    url = line.split(" ")[2]
                if line.count(".gkg.csv.zip") > 0:
                    gkg_url = line.split(" ")[2]
                if line.count(".mentions.CSV.zip") > 0:
                    mentions_url = line.split(" ")[2]


            if not url or not gkg_url:
                return
        else:
            if feed.count("translation") > 0:
                _from_date += ".translation"

            url = "http://data.gdeltproject.org/gdeltv2/{0}.export.CSV.zip".format(_from_date)
            mentions_url = "http://data.gdeltproject.org/gdeltv2/{0}.mentions.CSV.zip".format(_from_date)
            gkg_url = "http://data.gdeltproject.org/gdeltv2/{0}.gkg.csv.zip".format(_from_date)

        filename = download_file(url)
        filename_gkg = download_file(gkg_url)
        filename_mentions = download_file(mentions_url)
        if filename:
            unzip(filename)
            process_events(filename.strip('.zip'))
            os.remove(filename)
            os.remove(filename.strip('.zip'))

            unzip(filename_gkg)
            os.remove(filename_gkg)
            os.remove(filename_gkg.strip('.zip'))

            unzip(filename_mentions)
            os.remove(filename_mentions)
            os.remove(filename_mentions.strip('.zip'))

if __name__ == "__main__":
    """
    To download the current 15 mins update use (good for cron jobs):
    python gdelt_realtime_downloader.py
    To download a time range (good when cron jobs or internet connection fails :))
    python gdelt_realtime_downloader.py 2017-07-12T10:00 2017-07-12T11:00
    """
    if len(sys.argv) > 1:
        _from_date = datetime.datetime.strptime(sys.argv[1], "%Y-%m-%dT%H:%M")
        _to_date = datetime.datetime.strptime(sys.argv[2], "%Y-%m-%dT%H:%M")
        if _from_date > _to_date:
            raise Exception("{0} must be after {1}".format(_from_date, _to_date))

        while _from_date <= _to_date:
            get(_from_date.strftime("%Y%m%d%H%M%S"))
            _from_date = _from_date + datetime.timedelta(minutes=15)
    else:
        get()