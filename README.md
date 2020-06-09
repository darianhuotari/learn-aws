# learn-aws
Learning to automate AWS traditional, microservice, and serverless environments. Building a self-registration app using Flask and PostgreSQL. Inspired by [this Reddit post.](https://www.reddit.com/r/sysadmin/comments/8inzn5/so_you_want_to_learn_aws_aka_how_do_i_learn_to_be/)

# Traditional
Successully built load-balanced, auto-scaling site on EC2 which uses `Flask` for the front-end and `PostgreSQL` to store data. Currently tweaking Terraform code to fully automate proccess.

Next steps:

1 - Terraformize DNS entry creation based on postgres instance DNS name.

2 - Terraformize security group on postgres DB instance

3 - Use IAM roles to allow DB access instead of username / password?



To do: 

Serve from static S3 bucket. 

Enable SSL.

Terraformize both the above once tested and working.

# Microservice
Coming later.

# Serverless
Coming later.

# Credits
Using https://github.com/ricardbejarano/learn-aws/ and https://github.com/Azure-Samples/flask-postgresql-app for inspiration and python / flask code samples.
