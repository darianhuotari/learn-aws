# learn-aws
Learning to automate AWS traditional, microservice, and serverless environments. Building a self-registration app using Flask and PostgreSQL. Inspired by https://www.reddit.com/r/sysadmin/comments/8inzn5/so_you_want_to_learn_aws_aka_how_do_i_learn_to_be/

# Traditional
Successully built load-balanced, auto-scaling site on EC2 which uses flask for the front-end and postgres to store data. Currently tweaking Terraform code to fully automate proccess.

Next steps:

1 - Pass DB DNS name from Terraform into app.py. Idea - create DNS alias for DB in main.tf, and point flask config to alternate DNS name?

2 - Review security groups on DB resource

3 - Figure out a way to pass variables from Terraform, to avoid hard-coded passwords / connection strings.



To do: 
Serve from static S3 bucket. 
Use Route53 for DNS.
Enable SSL.

# Microservice
Coming later.

# Serverless
Coming later.

# Credits
Using https://github.com/ricardbejarano/learn-aws/ and https://github.com/Azure-Samples/flask-postgresql-app for ideas / examples.
