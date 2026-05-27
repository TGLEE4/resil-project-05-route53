# Project 5 — Route 53 Custom Domain + CloudFront + ACM

## Overview
Migrated the RESIL Technology Solutions business website from GitHub Pages to a 
production-grade AWS infrastructure stack. The site is now served globally via 
CloudFront CDN, secured with a free ACM SSL certificate, and DNS is fully managed 
by Route 53 — all provisioned with Terraform as Infrastructure as Code.

**Live Site:** https://tenglee.dev

---

## Goals
- Move business website off GitHub Pages onto AWS infrastructure
- Attach a custom domain to CloudFront using Route 53
- Issue and validate a free SSL/TLS certificate via ACM
- Achieve zero downtime migration — site stays live during switchover
- Provision all infrastructure with Terraform (no manual AWS console clicks)

---

## Tools & Environment
| Tool       | Version              |
|------------|----------------------|
| OS         | Ubuntu 24.04.4 LTS (WSL2) |
| Terraform  | v1.15.3              |
| AWS CLI    | 2.34.48              |
| Git        | 2.43.0               |
| GitHub CLI | 2.45.0               |

---

## Architecture

User types tenglee.dev
↓
Namecheap delegates DNS → Route 53 nameservers
↓
Route 53 Hosted Zone resolves Alias record
↓
CloudFront Distribution (global CDN, HTTPS enforced)
↓
S3 Bucket (static website hosting)
↓
RESIL Technology Solutions website served globally

---

## Infrastructure Built
| Resource | Purpose |
|----------|---------|
| `aws_acm_certificate` | Free SSL/TLS cert covering root + www domain |
| `aws_acm_certificate_validation` | Waits for DNS proof of domain ownership |
| `aws_s3_bucket` (root) | Hosts website files (index.html, logo) |
| `aws_s3_bucket` (www) | Redirects www → root domain over HTTPS |
| `aws_s3_bucket_policy` | Allows public read access to website files |
| `aws_cloudfront_distribution` | Global CDN serving site over HTTPS |
| `aws_route53_zone` | Hosted zone — DNS control for domain |
| `aws_route53_record` (root) | Alias A record → CloudFront |
| `aws_route53_record` (www) | Alias A record → CloudFront |
| `aws_route53_record` (validation) | ACM DNS validation records (auto-created) |

---

## File Structure

resil-project-05-route53/
├── .gitignore       # Excludes .terraform/, state files, .pem, .tfvars
├── main.tf          # All infrastructure resources
├── variables.tf     # Domain name, bucket name, region
├── outputs.tf       # Nameservers, CloudFront URL, live site URLs
└── README.md        # This file

---

## Step by Step — What I Did and Why

### Step 1 — Created project repo and folder structure
Created `resil-project-05-route53/` inside `~/resil-roadmap/`. Created `.gitignore` 
before `terraform init` — lesson learned from previous projects to prevent 
accidentally staging `.terraform/` directory. Initialized git and pushed initial 
structure to GitHub.

### Step 2 — Wrote variables.tf
Defined four variables: `aws_region`, `domain_name`, `bucket_name`, 
`www_bucket_name`. Using variables instead of hardcoding values keeps the code 
reusable — changing the domain requires editing one file, not hunting through 
hundreds of lines of Terraform.

### Step 3 — Wrote main.tf in six sections

**Section 1 — Two AWS providers**
Defined two providers: a default provider and an aliased `us_east_1` provider. 
ACM certificates for CloudFront are an AWS hard requirement to exist in `us-east-1` 
regardless of where other infrastructure lives. The alias lets us target that 
specific region just for the certificate resource.

**Section 2 — ACM Certificate**
Issued a free SSL/TLS certificate covering both `tenglee.dev` and 
`www.tenglee.dev` using DNS validation. DNS validation was chosen 
over email validation because it integrates directly with Route 53 — Terraform 
automatically creates the required validation DNS records without any manual steps.

**Section 3 — S3 Buckets**
Created two buckets. The primary bucket hosts the actual website files. The www 
bucket contains no files — its only job is to catch `www.` traffic and redirect it 
to the root domain over HTTPS. The `depends_on` block on the bucket policy ensures 
the public access block is created before the policy is applied, preventing a race 
condition that causes apply failures.

**Section 4 — CloudFront Distribution**
Configured CloudFront to serve the S3 website globally with HTTPS enforced. Set 
`viewer_protocol_policy = "redirect-to-https"` so any HTTP request automatically 
upgrades to HTTPS. Used `sni-only` SSL method — the alternative costs hundreds of 
dollars per month. Set `depends_on = [aws_acm_certificate_validation.cert]` so 
CloudFront waits for the cert to be fully validated before deploying — this was the 
critical fix after the first apply failed with `InvalidViewerCertificate`.

**Section 5 — Route 53 Hosted Zone + Records**
Created a hosted zone as the DNS container for the domain. Created Alias A records 
for both root and www pointing to CloudFront. Used Alias records instead of standard 
A records because CloudFront IPs can change — Alias records dynamically follow the 
AWS resource regardless of IP changes.

**Section 6 — ACM Certificate Validation**
Used `for_each` to loop through all domain validation options and automatically 
create the required DNS records in Route 53. This eliminates the need to manually 
create validation records. The `aws_acm_certificate_validation` resource tells 
Terraform to pause and wait until ACM confirms the certificate is fully issued before 
proceeding.

### Step 4 — Wrote outputs.tf
Defined six outputs: nameservers, CloudFront URL, live site URL, www URL, ACM ARN, 
S3 bucket name. The nameservers output was critical — after the hosted zone was 
created, these four values needed to be copied into Namecheap to hand off DNS 
control from Namecheap to Route 53.

### Step 5 — Targeted apply for Route 53 hosted zone only
Ran `terraform apply -target=aws_route53_zone.primary` first to get the nameservers 
before running the full apply. This was necessary because ACM validation requires 
DNS to be pointing at Route 53 before the full apply runs — otherwise ACM times out 
waiting for validation records it can never find.

### Step 6 — Updated Namecheap nameservers
Logged into Namecheap, changed nameserver setting from `Namecheap BasicDNS` to 
`Custom DNS`, and entered all four Route 53 nameservers. This delegates DNS authority 
for the domain from Namecheap to AWS Route 53. Propagation took approximately 
20-30 minutes to reach Google's DNS resolvers globally.

### Step 7 — Verified DNS propagation
Used `nslookup tenglee.dev 8.8.8.8` to query Google's DNS directly, 
bypassing local resolver cache. Waited until the response showed `awsdns` nameservers 
before running full `terraform apply` — running apply before propagation causes ACM 
to time out.

### Step 8 — Full terraform apply
Once DNS propagated, ran full `terraform apply`. ACM validated successfully, 
CloudFront deployed globally, Route 53 alias records connected everything. 
Infrastructure deployed completely.

### Step 9 — Uploaded website files to S3
Downloaded `index.html` and `RESILLogo2.png` from the live GitHub Pages site and 
uploaded them to the S3 bucket using `aws s3 cp`. Verified files appeared in S3 
before testing CloudFront.

### Step 10 — Verified live site
Confirmed site loaded correctly at the raw CloudFront URL 
(`https://d3lozy0nmqnitz.cloudfront.net`) before DNS fully propagated locally. 
Domain resolved correctly within 30 minutes on all external DNS resolvers.

---

## Tradeoff 1 — S3 Website Endpoint vs S3 REST API Endpoint for CloudFront Origin

**What this means:**
There are two ways to connect CloudFront to S3 as an origin:
- S3 Website Endpoint (`bucket.s3-website-us-east-1.amazonaws.com`)
- S3 REST API Endpoint (`bucket.s3.amazonaws.com`) with Origin Access Control (OAC)

**What we chose:** S3 Website Endpoint with `origin_protocol_policy = "http-only"`

**Why:** S3 website endpoints support index document routing natively — if a user 
hits `/about`, S3 returns `index.html` automatically. The REST endpoint requires 
additional Lambda@Edge configuration to handle this. For a single-page static site, 
the website endpoint is simpler and sufficient.

**The tradeoff:** The website endpoint requires the S3 bucket to be publicly 
accessible. The REST endpoint with OAC keeps the bucket private — only CloudFront 
can read it. For a production business site with sensitive assets, OAC is the more 
secure approach. For a public static website like this one, the simpler public 
bucket approach is acceptable.

---

## Tradeoff 2 — DNS Validation vs Email Validation for ACM

**What this means:**
ACM offers two ways to prove you own a domain before issuing a certificate:
- DNS Validation — add a CNAME record to your DNS
- Email Validation — click a link sent to admin@yourdomain.com

**What we chose:** DNS Validation

**Why:** DNS validation integrates directly with Route 53. Terraform automatically 
creates the required CNAME records using `for_each` on 
`domain_validation_options` — zero manual steps. The certificate also auto-renews 
as long as the DNS record exists, with no human action required.

**The tradeoff:** DNS validation requires control of the domain's DNS — which we 
have via Route 53. Email validation is simpler if you don't control DNS but requires 
someone to manually click a link every time the cert renews (every 13 months). For 
infrastructure managed with Terraform, DNS validation is always the better choice 
because it keeps the entire lifecycle automated.

---

## Lessons Learned
- ACM certificates for CloudFront **must** be in `us-east-1` — hard AWS requirement
- `depends_on = [aws_acm_certificate_validation.cert]` not `.cert` — CloudFront must 
  wait for validation, not just creation
- Always update Namecheap nameservers **before** running full `terraform apply` — 
  ACM cannot validate if DNS isn't pointing at Route 53 yet
- Use `nslookup domain 8.8.8.8` to check real propagation status — local resolver 
  cache is unreliable
- Local browser DNS cache can lag 30-60 minutes behind global propagation — test 
  with CloudFront URL first to confirm infrastructure works independently of DNS

---

## How to Deploy

```bash
# Clone the repo
git clone https://github.com/TGLEE4/resil-project-05-route53.git
cd resil-project-05-route53

# Initialize Terraform
terraform init

# Deploy Route 53 hosted zone first
terraform apply -target=aws_route53_zone.primary

# Copy nameservers to your domain registrar
terraform output nameservers

# Wait for DNS propagation (verify with nslookup domain 8.8.8.8)
# Then run full apply
terraform apply

# Upload website files
aws s3 cp index.html s3://your-domain.com/
aws s3 cp logo.png s3://your-domain.com/

# Destroy when done
terraform destroy
```

---

## Live Site
https://tenglee.dev