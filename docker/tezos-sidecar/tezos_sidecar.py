from flask import Flask, escape, request
import requests
import datetime
from dateutil import parser

application = Flask(__name__)

@application.route('/has_peers')
def peer_checker():
    try:
        r = requests.get('http://127.0.0.1:8732/network/peers')
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
        r = requests.get('http://127.0.0.1:8732/chains/main/is_bootstrapped')
    except requests.exceptions.RequestException as e:
        err = "Could not connect to node, %s" % repr(e), 500
        print(err)
        return err
    if not r.json()["bootstrapped"]:
        err = "Chain is not bootstrapped", 500
        print(err)
        return err
    return "Chain is bootstrapped"
