This repository is a Next.js project used for testing Next.js framework alongside AWS Services: Fargate, Lambda, Lambda@Edge.

The testing was summarized in the blog post, whose contents are also part of this repository in [BLOG.md](_blog/BLOG.md).

## Contents

Besides the Next.js project itself (created by `npx create-next-app@latest`) it also contains:

### Stacktape configuration files

Repo contains Stacktape configuration files to **deploy the Next.js app in multiple ways into your own AWS account**:

- Deploy in Fargate container (file `env-container.stacktape.yml`)
- Deploy in Lambda function (file `env-lambda.stacktape.yml`)
- Deploy in Lambda@Edge function (file `env-edge-lambda.stacktape.yml`)

You can deploy any of these environments easily using [Stacktape](https://stacktape.com/) command:

```bash
stacktape deploy --configPath <<path_to_config>> --stage test
```

Additionally, the file `_helper-env/ec2-instance.stacktape.yml` can be used to deploy an EC2 instance (used for sending requests and testing the Next.js app in our tests).

You can connect easily to the deployed EC2 instance using the command:

```bash
stacktape bastion:session --configPath _helper-env/ec2-instance.stacktape.yml --stage test
```

### Testing scripts

Folder `_test-scripts` contains scripts that were copied to our helper EC2 instances and used for testing.

Running `test2.js` script requires you to have [autocannon](https://www.npmjs.com/package/autocannon) npm package installed on the system.

### Blog post content and resource

The testing was summarized in the blog post, whose contents are also part of this repository in [BLOG.md](_blog/BLOG.md).
