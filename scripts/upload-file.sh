#!/bin/sh

#curl -s -X POST https://rdr6vopsh7g5fuzouihruw3bn40hwjjh.lambda-url.us-east-1.on.aws/ -H "Content-Type: application/json" -d "`cat $1`"

#curl -X POST --aws-sigv4 $AWS_REGION --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" -H "Content-Type: application/json" -d "`cat $1`" http://gbrls.space

#curl -X POST "https://rdr6vopsh7g5fuzouihruw3bn40hwjjh.lambda-url.us-east-1.on.aws" --aws-sigv4 "$AWS_REGION" --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" -d "`cat $1`"

awscurl --service lambda -X POST "https://rdr6vopsh7g5fuzouihruw3bn40hwjjh.lambda-url.us-east-1.on.aws" -d "`cat $1`"



