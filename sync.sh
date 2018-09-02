#!/usr/bin/env bash

DUMP_FILE=db.dump

pg_dump -v -Fc $DATABASE_URL > $DUMP_FILE

aws s3 cp $DUMP_FILE $S3_PATH
