from flask import Flask, escape, request
import requests
import datetime
from dateutil import parser

application = Flask(__name__)

@application.route('/has_peers')
def peer_checker():
    try:
        r = requests.get('http://localhost:8732/network/peers')
    except requests.exceptions.RequestException as e:
        err = "Could not connect to node, %s" % repr(e), 500
        print(err)
        return err
    number_of_peers = len(r.json())
    if number_of_peers < 1:
        err = "We don't have any peer", 500
        print(err)
        return err
    return str(number_of_peers)

@application.route('/is_synced')
def sync_checker():
    try:
        r = requests.get('http://localhost:8732/chains/main/blocks/head')
    except requests.exceptions.RequestException as e:
        err = "Could not connect to node, %s" % repr(e), 500
        print(err)
        return err
    most_recent_block_date = parser.isoparse(r.json()["header"]["timestamp"])
    now = datetime.datetime.now(datetime.timezone.utc)
    last_block_age_in_seconds = (now - most_recent_block_date).total_seconds()
    if last_block_age_in_seconds > 240:
        err = "Last block is %s seconds old, which is over the limit of 240" % last_block_age_in_seconds, 500
        print(err)
        return err
    return str(last_block_age_in_seconds)
