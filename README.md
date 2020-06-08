# learn-aws
Learning to automate AWS traditional, microservice, and serverless environments. Building a self-registration app using Flask and PostgreSQL. Inspired by https://www.reddit.com/r/sysadmin/comments/8inzn5/so_you_want_to_learn_aws_aka_how_do_i_learn_to_be/

# Traditional
Successully built load-balanced, auto-scaling site on EC2 which uses flask for the front-end and postgres to store data. Currently working on automating the entire provisioning process via Terraform.

Next steps:
1 - Test terraform code
2 - Can't auto-create tables from Terraform; must be created another way (app.py?)
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
