#!/bin/sh

curl -s -X POST https://rdr6vopsh7g5fuzouihruw3bn40hwjjh.lambda-url.us-east-1.on.aws/ -H "Content-Type: application/json" -d "`cat $1`"
