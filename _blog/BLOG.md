# Performance comparison: Next.js alongside Fargate, Lambda and Lambda@Edge

In this article, we'll explore how Next.js, a popular React framework, works alongside key AWS services: **Lambda**, **Lambda@Edge**, and **Fargate**. These technologies play a vital role in modern web development, offering serverless and containerized solutions.

Our aim is to help developers understand the performance impact of combining [Next.js](https://nextjs.org/) with these AWS services. We'll dive into the technical details, providing practical examples and benchmarks to empower developers in making informed decisions for building high-performance, serverless web applications.

## Deployment options

For those of you who are not familiar with Next.js, here is a quick overview of deployment options when using Next.js.

As a developer deploying Next.js app, you can choose between:

1. fully managed solutions for a hassle-free experience or
2. self-managed setups for complete control (can still be hassle-free, read on)

### Fully managed solutions

![Monkey meme](resources/shock-vercel.jpg)

When it comes to deployment of Next.js application, [Vercel](https://vercel.com/) (comes from the creators of Next.js) stands out as the de facto standard, providing a seamless experience with its user-friendly interface, automatic scaling, and many other features. [Netlify](https://www.netlify.com/) (and some other PaaS web hosting providers) also provides a similar solution.

While both Vercel and Netlify have a generous free tiers and are great for many projects (I used them personally) there are a few things that could be a no-go for some (especially larger) projects:

- Both Vercel and Netlify can get pricey once you get out of the free tier.
- In the free tier, Vercel does not allow for using ads on your site.
- If you need private VPC for compliance, security, or other reasons, you will probably need to opt into an expensive enterprise subscription.

There may also be other reasons why **these managed solutions are not usable for your use case**. That is why today, we will look at self-hosting in your own AWS account.

### Self-managed setup

If for some reason you are unable/do not wish to use the fully managed solutions, you can always self-host your app on a cloud/service of your choice (in this post, we will focus on AWS). The main advantages of self-hosting are:

- **Flexibility** - integrate easily with any other backend services offered by the cloud.
- **Lower costs** - much cheaper than Vercel or Netlify (especially at scale).

The recommended self-hosting approach by the creators of Next.js is to **containerize your app** and deploy it anywhere you need - allowing you to deploy your app basically anywhere. It is an easy approach that can also be reasonably cheap.

**The problem: While with Vercel or Netlify your website is basically free when you have very low or no traffic at all, for the container you have to pay even if it is running idly.**

Throughout the existence of Next.js, there were multiple attempts to provide developers a way to **self-host** their Next.js app using AWS Lambda, giving you the benefits of Vercel...

- you only pay for what you use (pay per request)
- unrestricted scaling(almost) tailored to your needs (thanks to the serverless nature of Lambda functions)

... but for a lower price.

![Developer Lambda hosting](resources/lambda-developer.jpg)

Unfortunately, **packaging the Next.js app to make it runnable in AWS Lambda is not a trivial problem to solve** due to the nature and internal functioning of the Next.js framework.

On the forefront of open-source projects solving this non-trivial problem is [OpenNext](https://open-next.js.org/) - an adapter that enables developers to build and run the Next.js app using AWS Lambda function. However, setting up the infrastructure with this adapter is not straightforward. The [architecture](https://docs.stacktape.com/compute-resources/nextjs-website/#under-the-hood) is fairly complex, especially for developers without a cloud background.

Luckily tools such as [Stacktape](https://stacktape.com/) (full disclosure, I am one of the developers) or [SST](https://sst.dev/) (also creators of OpenNext) have integrated OpenNext into their resources giving developers a way to host the Next.js app using AWS Lambda a breeze.

---

## Test environments

In our test, we will be comparing 3 deployment setups of the Next.js app:

| #   | Environment type          | Configuration                             | Example Project to Deploy                                                            |
| --- | ------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------------ |
| 1   | AWS Lambda                | 1024 MB memory, build using OpenNext      | [example project](https://github.com/stacktape/starter-nextjs-ssr-website-lambda)    |
| 2   | AWS Lambda@Edge           | 1024 MB memory, build using OpenNext      | [example project](https://github.com/stacktape/starter-nextjs-ssr-website-lambda)    |
| 3   | AWS ECS Fargate container | 0.5 CPU, 1024 MB memory, HTTP API Gateway | [example project](https://github.com/stacktape/starter-nextjs-ssr-website-container) |

All of our environments are set in the `eu-west-1`(Ireland) region, which means most of the infrastructure is localized in this region (understandably the Lambda@Edge must be set up in the `us-east-1` region).

All of our environments are production-ready and have CDN enabled. However, since we are measuring the performance of the underlying compute engines, **we will send requests directly to the Lambda/Container origins, to simulate the way CloudFront(CDN) sends requests to these origins**.

Additionally, we have set up two EC2 instances to interact(send requests) with our Next.js app: one in each `eu-west-1`(Ireland) and `us-east-1`(Virginia) region.

---

## Test 1 - Request/response time

<!-- In the first test, we will measure latency (response time) by sending requests to the Next.js app. -->

The goal of the test is to compare average response time from the origins across the environments, when the load is low.

For regular **Lambda** and **Container** environments we will conduct the test twice:

- **from the region where environment is deployed** (`eu-west-1`) - simulates a request from a user that is geographically close to the environment
- **from region distant from environment** (`us-east-1`) - simulates a request from a user that is geographically far away from the environment

For the **Lambda@Edge** environment we will only conduct one test:

- **from region distant from environment** (`us-east-1`) - simulates a request from a user that is geographically far away from the environment, but the Lambda function runs at the Edge closer to the user
- we will not be conducting the test from `eu-west-1`. Considering the way we are testing, the test would be equal to the regular Lambda test above.

> Note that we are omitting the first response time due to Lambda functions [cold starts](https://docs.aws.amazon.com/lambda/latest/operatorguide/execution-environments.html#cold-start-latency). Cold starts can be lengthy, especially considering that the Next.js app Lambda zip package can be quite hefty (reducing the package size is one of the things that the OpenNext community is working on). **The cold starts are something to consider, but for the purposes of this test, it would skew our results.** In production environments, the problem with cold starts can be mitigated by using [warmer](https://docs.stacktape.com/compute-resources/nextjs-website/#using-warmer).
>
> Requests are sent one at a time in a following way:
>
> - For `Container` environment we will send requests to `HTTP API Gateway` which delivers traffic to containers.
> - For `Lambda` environments we will use `Lambda URL` (we realize that calling Lambda URL is not the way Cloudfront calls the Lambda@Edge, but it is the closest we can get ATM).

### Results

| Origin                        | Requests from | Avg. Latency (ms) |
| ----------------------------- | ------------- | ----------------- |
| Ireland Container             | Ireland       | 57.94             |
| Ireland Lambda                | Ireland       | 86.27             |
| Virginia Lambda (Lambda@Edge) | Virginia      | 317.45            |
| Ireland Container             | Virginia      | 377.83            |
| Ireland Lambda                | Virginia      | 432.91            |

The results show that if request originates in the same region where environment is deployed, you will get the fastest response (obviously). While container seems to be a bit faster, difference is not marginal.

But what is happening in the **Lambda@Edge** environment? **The request is processed in the region of its origin, so why does it take longer to get the response?** To answer this, we need to understand the infrastructure behind using OpenNext and Lambda@Edge.

First, we need to understand some internals (namely internal caching) of Next.js.

### Next.js caching

To improve your application's performance and to reduce costs Next.js employs multiple mechanisms for caching rendered work and data requests on the server. The full list of all caching mechanisms can be found in [Next.js docs](<(https://nextjs.org/docs/app/building-your-application/caching#overview)>)

The caching mechanisms we are interested in are:

1. Data Cache - built-in Data Cache that **persists** the result of data fetches across incoming server requests and deployments.
2. Full Route Cache - Next.js automatically renders and caches routes at build time.

<!-- This is possible because Next.js extends the native fetch API to allow each request on the server to set its own persistent caching semantics. -->
<!-- This is an optimization that allows you to serve the cached route instead of rendering on the server for every request, resulting in faster page loads. -->

![Next.js caching mechanisms](resources/caching-overview.png)

### Lambda cache problem

Traditionally, the cache is persisted on the server that serves the Next.js. This is also the case for our **Container** environment.

However, since AWS Lambda functions do not have persistent storage, OpenNext developers came up with the solution to use S3 bucket as a global storage to be used by all Lambda invocations for storing and retrieving the cached data.

This solution has a small caveat when using Lambda@Edge. **When the cache bucket is located in different region to where the Lambda is executing, Lambda must retrieve the cache data across the region - resulting in increased latency.** That being said, test also shows that request/response is **still faster using Lambda@Edge** compared to sending entire request and getting response from the other region. Moreover, with routes where you do not use cache at all, using Lambda@Edge can be significantly faster.

![Edge lambda cache bucket](resources/next-edge-lambda-cache-bucket.png)

---

## Test 2 - Load testing

When it comes to Lambda environments, the potential for scaling is huge and there are basically no (hard) limits. What's more, is that **every incoming request has the full memory and CPU power of Lambda function at its disposal**. This means that even if you are performing more resource-intensive operations (DB operations, processing...), you can rely on resources being available.

On the other hand, when using a container, all of the requests are coming to the same container, hence the resources of the container are shared between the incoming requests.

> In real life scenario, you can scale your containers easily either vertically (giving more resources to the container) or more commonly horizontally (**adding more containers and spreading the load between them**). In our test, we will not be using any horizontal/vertical scaling for our container, as we want to see how much a single container can take.

To generate traffic for load testing we will be using the NodeJS HTTP benchmarking tool [autocannon](https://www.npmjs.com/package/autocannon) with the following options:

- **pipelining** - to increase the load, we will set pipelining to 10. This means that each connection can send up to 10 requests without waiting for a response.
- **connections** - to control the requests per second, we will be adjusting(increasing) the number of connections (we will use the following number of connections: 3, 10, 30, 50, 100, 200, 300, 500)

Tests will be carried out for **Lambda** and **Container** environments from our EC2 instance in the `eu-west-1` region. Testing the **Lambda@Edge** environment is not possible (the test would be the same as for the **Lambda** environment).

- Each test takes 60 seconds.
- Each request will target the same route path (root `/`). In other words, each request should target the `index` page of our Next.js app.
- We will observe how the increasing load impacts both **latency**, **error rate** and search for thresholds of each environment.

### Results

![Latencies - increased load](resources/latency_plot.png)

#### Lambda

The worse performance of Lambda in this test (container has better latencies when load is lower) is a question mark since the average duration of Lambda (observed in AWS Cloudwatch metrics) is **around 25ms**. Therefore having an overall **latency of ~300ms** when the load is low is somewhat surprising. The cold starts could be affecting the average, but even the **minimal latency in the tests was over 200ms**. This would suggest that the latency delay happens not during Lambda execution, but somewhere else. Whether this is due to some Lambda URL limitations, standard network delay or something else, we were not able to find out.

At around 200 connections (~6000 req/sec) we can see that the Lambda latency starts to increase. We were not able to get through ~6500 req/sec. The logical explanation is Lambda Throttling, but we only got around one or two `429 Error`(Throttling Error code) out of more than 250,000 requests. Our next guess was that the duration of lambda increased due to overloading **S3 cache bucket** which in turn caused increase of latency. This guess was wrong, as the Lambda average duration only rose to about ~30ms during high load.

Our conclusion right now is that **this in fact is due to Lambda Throttling**. It seems that Lambda URL (gateway mechanism behind it) simply **waits until Lambda can be executed (instead of sending 429 Error)** using some queuing mechanism - which would explain both: why we are not getting many `429 Errors` and why there is a latency increase. However, we were unable to find any resources confirming this, only an [unanswered question on AWS forum](https://repost.aws/questions/QUcL83FbaRTratTYprSLN-BA/lambda-function-url-throttling) asking basically about the same thing.

#### Container

The previous graph shows, that as the traffic is ramping up, the average latency for the container starts to rise. We can see that already at around 70 connections (~700 req/sec) we are getting to the **1-second latency**. From there on, the latency rises quite quickly. In the next graph, you will see that the error rate (amount of 503 errors) due to overload goes up as well.

![Processed requests](resources/request_response_plot_sqrt.png)

This graph also confirms that the container is able to process around 4500 requests per minute which corresponds to the ~700request/sec threshold, we estimated from previous graph.

> It should be noted that the our simulation conditions might not be completely the same as what users experience in their Next.js app. User's production app might be generally more complex - fetching data from APIs and databases, or performing more resource-intensive operations.

---

## Test 3 - Pricing

Rather than a test, this section is more of pricing comparison between the environments based on our previous tests and AWS pricing info.

Let's start by creating formulas for calculating the price of environments.

We will be comparing 4 environments:

1. Lambda environment (OpenNext)
2. Lambda@Edge environment (OpenNext)
3. Fargate container + HTTP API Gateway
4. Fargate container + Application Load Balancer price

> We have added the environment with `Fargate container + Application Load Balancer`, as we wanted to provide a better picture for our reader (HTTP API Gateway can easily be swapped with Application Load Balancer).

### Lambda environment price

Official information from AWS:

- the cost of 1ms of Lambda execution (with memory 1024MB as used in the test) is ~$0.0000000167,
- the cost of Lambda per million requests is $0,2,
- the cost of the S3 bucket: $0,0004 per 1000 GET requests and $0,005 per 1000 PUT requests.

Breakdown of formula for monthly costs (where x is number of requests per month):

|     | Formula                                               | Description                                                                                                       |
| --- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| +   | `average_lambda_function_duration * 0.0000000167 * x` | Price for execution time                                                                                          |
| +   | `0.0000002 * x`                                       | Price for each request                                                                                            |
| +   | `x * 0.0004 / 1000 + x / 50 * 0.005 / 1000`           | Price for cache bucket (Assuming 1 GET request per client request and 1 PUT request for every 50 client requests) |

<!-- Final formula (where x is number of requests per month):

`(average_lambda_function_duration * 0.0000000167 * x) + (0.0000002 * x) + (x * 0.0004 / 1000) + (x / 50 * 0.005 / 1000)` -->

### Lambda@Edge environment price

Official information from AWS:

- the cost of 1ms of Lambda execution (with memory 1024MB as used in the test) is ~$0.00000005001,
- the cost of Lambda per million requests - $0,6,
- the cost of the S3 bucket: $0,0004 per 1000 GET requests and $0,005 per 1000 PUT requests.

Breakdown of formula for monthly costs (where x is number of requests per month):

|     | Formula                                                | Description                                                                                                       |
| --- | ------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| +   | `average_lambda_function_duration * 0.00000005001 * x` | Price for execution time                                                                                          |
| +   | `0.0000006 * x`                                        | Price for each request                                                                                            |
| +   | `x * 0.0004 / 1000 + x / 50 * 0.005 / 1000`            | Price for cache bucket (Assuming 1 GET request per client request and 1 PUT request for every 50 client requests) |

<!-- Final formula (where x is number of requests per month):

`(average_lambda_function_duration * 0.00000005001 * x) + (0.0000006 * x) + (x * 0.0004 / 1000) + (x / 50 * 0.005 / 1000)` -->

### Fargate container + HTTP API Gateway price

Official information from AWS:

- the cost of the Fargate container we used in our test is ~$0,0244/hour or ~$17,5/month,
- the cost of HTTP API Gateway is $1 for 1 000 000 requests.

Breakdown of formula for monthly costs (where x is number of requests per month):

|     | Formula                                                                              | Description                                                                |
| --- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| +   | `17.5 * ceil((x+1) / (2592000 * number_of_req_per_sec_handled_by_single_container))` | Fees for Fargate container (2592000 is the number of seconds in the month) |
| +   | `x / 1000000`                                                                        | Price for HTTP API Gateway                                                 |

<!-- Final formula (where x is number of requests per month):

`17.5 * ceil((x+1) / (2592000 * number_of_req_per_sec_handled_by_single_container)) + x / 1000000` -->

### Fargate container + Application Load Balancer price

Official information from AWS:

- the cost of the Fargate container we used in our test is ~$0,0244/hour or ~$17,5/month,
- the cost of Application Load Balancer is $16,2 + 0,008LCU/hour(or 5,76/month).

Breakdown of formula for monthly costs (where x is number of requests per month):

|     | Formula                                                                              | Description                                                                |
| --- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| +   | `17.5 * ceil((x+1) / (2592000 * number_of_req_per_sec_handled_by_single_container))` | Fees for Fargate container (2592000 is the number of seconds in the month) |
| +   | `16.2`                                                                               | Flat monthly fee for Application Load Balancer                             |
| +   | `x / (2592000 * 1000) * number_of_lcus_needed_for_thousand_req_sec * 5.76`           | Fee for LCUs                                                               |

<!-- Final formula (where x is number of requests per month):

`17.5 * ceil((x+1) / (2592000 * number_of_req_per_sec_handled_by_single_container)) + 16.2 + x / (2592000 * 1000) * number_of_lcus_needed_for_thousand_req_sec * 5.76` -->

### Pricing Comparison

We will now visualize the above formulas in the graph, but first, we need to set the constants we introduced:

- `average_lambda_function_duration` - In our tests the average lambda duration was around 27ms. However, in real scenarios, the average lambda duration might be higher, since you will be generating more complex websites and fetching data from APIs and databases. We will set it to **50ms** for this simulation.

- `number_of_lcus_needed_for_thousand_req_sec` - we will set this to **50**. This can be more or less according to the amount of data you will be transferring on average in each request.

- `number_of_req_per_sec_handled_by_single_container` - In our tests the container was able to handle more than 500 req/sec. However, as with the `average_lambda_function_duration`, in real life, these values might differ due to more complex operations being done in production environment. We will set this to **100**.

![Pricing comparison](resources/pricing-comparison-50-50-100.png)

We can see that if the average load is low, the Lambda environments are the cheapest. This is actually the case for most of the websites, especially **since in production most of the content will be cached on CDN**. In cases where you cannot use caching, you have lower revalidation intervals, or your Next.js app is API heavier, the Lambda environment can cost you more than you would like. Already at 3 requests/second(Lambda@Edge) and 9 requests/second(Lambda), using containers with a load balancer seems to be a more suitable option.

> For many production websites, there might not be many requests coming to the origin since most of content is cached on CDN, so using Lambda might be cheapest.

It is important to note that the graph can look very differently if you change the constants, that we have set. For example changing `average_lambda_function_duration`, `number_of_req_per_sec_handled_by_single_container` or increasing/decreasing requests sent to cache bucket - **all these constants depend on your specific setup and influence the final price**.

The following graph uses the same formulas but `average_lambda_function_duration` is set to **30ms** and `number_of_req_per_sec_handled_by_single_container` is set to **50**.

![Pricing comparison - adjusted constants](resources/pricing-comparison-30-50-50.png)

You should also note that our price estimations do not include Data Transfer fees that you will receive from AWS as these should be similar for all environments and are not a differentiator.

> Note that there are multiple optimizations that would influence the price of your setup. For example pushing the price of the container down by using EC2 instances instead of Fargate - a `t3` instance with comparable performance costs around ~$0.0104/hour or ~$7,5/month etc.

---

## Conclusion

Our tests have provided a glimpse of the performance abilities of multiple Next.js hosting options on AWS. As mentioned multiple times in the article, results with your Next.js app might vary depending on many factors that come into evaluation.

What we took from the tests (bottom line):

- Lambda environments are ideal if:
  - you do NOT have an continuos traffic load of at least 5-10 requests per second coming to the Lambda (**this is the case for most webs as your content will get cached on CDN**),
  - you need very fast scaling due to your load being unpredictable (Lambda can scale instantly compared to adding more containers),
  - Lambda@Edge can get expensive quickly - use it only if users of your app are dispersed across the globe and you can benefit from Edge capabilities.
- Container environments are ideal if:
  - you have a sustainable average traffic load of more than 5-10 requests per second coming to your container,
  - you cannot afford Lambda cold starts,
  - your traffic load is more predictable and there are not sudden spikes (slower scaling).

If you got until here, thank you! Let us know if we did some mistake in the testing or if you are interested in some more comparisons and tests.
