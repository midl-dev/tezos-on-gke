#!/bin/bash

mkdir website_archive
pushd website_archive
wget -qO- $WEBSITE_ARCHIVE |  tar xvz 
popd

mv $(find website_archive/ -mindepth 1 -type d | head -1) website

rm -rvf website_archive

mkdir website/payouts

wget $PAYOUT_URL

python3 /createPayoutPages.py $(pwd)/website/payouts

pushd website

jekyll build -d ../_site

popd

find

# send website to google storage for website serving
gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS

gsutil rsync -R _site gs://$WEBSITE
