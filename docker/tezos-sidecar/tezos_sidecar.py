from flask import Flask, escape, request
import requests
import datetime
from dateutil import parser

application = Flask(__name__)

@application.route('/has_peers')
def peer_checker():
    r = requests.get('http://localhost:8732/network/peers')
    number_of_peers = len(r.json())
    if number_of_peers < 1:
        raise Exception("We don't have any peer")
    return str(number_of_peers)

@application.route('/is_synced')
def sync_checker():
    r = requests.get('http://localhost:8732/chains/main/blocks/head')
    most_recent_block_date = parser.isoparse(r.json()["header"]["timestamp"])
    now = datetime.datetime.now(datetime.timezone.utc)
    last_block_age_in_seconds = (now - most_recent_block_date).total_seconds()
    if last_block_age_in_seconds > 240:
        raise Exception("Last block is %s seconds old, which is over the limit of 240" % last_block_age_in_seconds)
    return str(last_block_age_in_seconds)
