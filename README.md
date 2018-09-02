## postgres-local-sync

Heroku helper app that makes a backup of a staging database, publishes that to S3, and allows easy download for developers using curl and the Heroku CLI.

**Note:** This doesn't do anything fancy, its just a convenient helper script, especially when using Amazon RDS + Heroku.

### Setup

First make sure you have provisioned a suitable S3 bucket without public access, and create an IAM user that can write to the bucket. For the IAM policy you can use something like this:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::my-sync-bucket"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::my-sync-bucket/*"
            ]
        }
    ]
}
```

Then provision a new Heroku app, run the following, and then deploy this repository to it:

```
heroku buildpacks:set https://github.com/lfittl/heroku-buildpack-awscli.git
heroku config:set AWS_DEFAULT_REGION=us-east-1
heroku config:set AWS_ACCESS_KEY_ID=...
heroku config:set AWS_SECRET_ACCESS_KEY=...
heroku config:set S3_PATH=s3://my-sync-bucket/staging.dump

# Either set DATABASE_URL directly, or attach an add-on if using Heroku Postgres
heroku config:set DATABASE_URL=postgres://...
```

### Usage

Either use the Heroku scheduler to run the `sync` task once a day, or run `sync` manually before calling `sync_url` to get the download URL.

Use this as follows to refresh your local development database:

```bash
heroku run sync # Optional
curl -o tmp/latest.dump `heroku run --no-notify --no-tty sync_url 2> /dev/null`
pg_restore --verbose --no-acl --no-owner -h localhost -p 5432 -U postgres -d postgres tmp/latest.dump
```

If you use Ruby on Rails, a full example of a useful `database:sync` rake task can be found in `database.rake` (copy into your codebase to use).

### LICENSE

Copyright (c) 2018, Lukas Fittl lukas@fittl.com
postgres-local-sync is licensed under the 3-clause BSD license, see LICENSE file for details.
