# learn-aws
Learning to automate AWS traditional, IaaS (Elastic Beanstalk / Kubernetes), microservice, and serverless environments. Built a self-registration app using Flask and PostgreSQL. Deployed onto AWS using Terraform. Inspired by [this Reddit post.](https://www.reddit.com/r/sysadmin/comments/8inzn5/so_you_want_to_learn_aws_aka_how_do_i_learn_to_be/)

# Traditional
Successully built load-balanced, auto-scaling self-registration portal which uses `Flask` for the front-end and `PostgreSQL` to store data. Uses EC2 for compute, load-balancing, and autoscaling, RDS / PostgreSQL to store data, Route53 for DNS, CloudFront to cache data, and ACM for certificates. Using Terraform to fully automate proccess.

Next steps:

1 - Cleanup main.tf names / variables

2 - Use IAM roles to allow DB access instead of username / password?



# IaaS
Coming later.


# Containers / Kubernetes
Coming later.


# Microservice
Coming later.


# Serverless
Coming later.


# Credits
Using https://github.com/ricardbejarano/learn-aws/ and https://github.com/Azure-Samples/flask-postgresql-app for inspiration and python / flask code samples.
