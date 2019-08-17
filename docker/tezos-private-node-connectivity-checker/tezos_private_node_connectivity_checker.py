from flask import Flask, escape, request
import requests

application = Flask(__name__)

MIN_NUM_PEERS=1

@application.route('/')
def checker():
    r = requests.get('http://localhost:8732/network/peers')
    number_of_peers = len(r.json())
    if number_of_peers < MIN_NUM_PEERS:
        raise Exception("We don't have %s peers" % MIN_NUM_PEERS)
    return str(number_of_peers)
