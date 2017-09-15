#! /bin/bash

bundle exec jekyll build
# s3fs davidb-da2a06dd /mnt/s3-davidb

aws s3 sync _site/ s3://blog.davidb.org/
