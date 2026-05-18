# static-site-bootstrap

Reusable template for hosting a static website on AWS with **S3**, **CloudFront**, **ACM (HTTPS)**, and **Route 53**.

Each new site is mostly: register a domain, set a few config values, run Terraform once, then deploy HTML/CSS/JS with a single script.

## What this creates

| Resource | Purpose |
|----------|---------|
| S3 bucket | Private storage for site files (not public; CloudFront reads via OAC) |
| CloudFront | CDN, HTTPS, `index.html` as default root |
| ACM certificate | TLS for apex + `www` (issued in `us-east-1`, required for CloudFront) |
| Route 53 records | Apex (A/AAAA alias), `www` (CNAME), and ACM DNS validation |

**Not included:** domain registration itself (see below). Terraform expects a **public Route 53 hosted zone** for your domain to already exist.

## Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured (`aws sts get-caller-identity` works)
- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.5`
- An AWS account with permissions for S3, CloudFront, ACM, Route 53, and IAM policy documents

## Project layout

```
.
├── deploy.sh                 # Sync site/ → S3, invalidate CloudFront cache
├── deploy.env.example        # Optional manual bucket/distribution overrides
├── site/                     # Your static site (must include index.html)
└── infra/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars.example
```

## New site checklist

### 1. Register the domain (AWS Console)

Terraform does **not** register new domains. Use Route 53 as registrar (or transfer a domain in later).

1. Open [Route 53 → Registered domains](https://console.aws.amazon.com/route53/home#DomainListing:) in the AWS Console.
2. Click **Register domains** (or **Transfer domain** if you already own it elsewhere).
3. Search for the name, add to cart, and complete checkout (contact info, privacy options, etc.).
4. Wait for registration to finish (often minutes; can take up to a few days for some TLDs).
5. Confirm a **public hosted zone** exists: [Route 53 → Hosted zones](https://console.aws.amazon.com/route53/v2/hostedzones). Registering through Route 53 usually creates this automatically.

**Domain registered outside AWS?** Create a hosted zone in Route 53 for your domain, then at your registrar update the domain’s **nameservers** to the four NS values Route 53 shows for that zone. DNS must point to Route 53 before ACM validation and alias records will work.

### 2. Configure Terraform

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

| Variable | What to set |
|----------|-------------|
| `domain_name` | Root domain, e.g. `example.com` (no `www`, no trailing dot) |
| `site_bucket_name` | Globally unique S3 bucket name, e.g. `example-com-site` (lowercase, hyphens; must not exist in any AWS account) |
| `region` | Usually `us-east-1` (S3 + Route 53 lookups; ACM for CloudFront is always `us-east-1` in code) |

`terraform.tfvars` is gitignored so each clone/site can have its own values.

### 3. Provision infrastructure

From `infra/`:

```bash
terraform init
terraform plan    # review: cert, CloudFront, S3, Route 53 records
terraform apply
```

First apply can take several minutes (ACM DNS validation + CloudFront distribution).

Useful outputs after apply:

```bash
terraform output site_bucket_name
terraform output cloudfront_distribution_id
terraform output cloudfront_domain_name   # test via https://d123....cloudfront.net before DNS propagates
```

### 4. Add your site files

Put your built static site in `site/` with `index.html` at the root. Replace the placeholder files in this repo.

### 5. Deploy content

From the **repo root**:

```bash
./deploy.sh
```

`deploy.sh` reads `site_bucket_name` and `cloudfront_distribution_id` from Terraform state in `infra/`. It:

1. Syncs `site/` → S3 (`--delete` removes objects removed locally)
2. Creates a CloudFront invalidation for `/*`

**Optional:** copy `deploy.env.example` to `deploy.env` to set `BUCKET` and `DISTRIBUTION_ID` manually (also gitignored).

## Day-to-day workflow

After infrastructure exists:

1. Edit files under `site/`
2. Run `./deploy.sh` from the repo root

To change DNS, TLS, or CDN settings, edit `infra/` and run `terraform plan` / `terraform apply` again.

## Using this template for another project

1. Copy or clone this repository.
2. Follow the [New site checklist](#new-site-checklist) with the new domain and bucket name.
3. Keep `infra/terraform.tfvars` and `deploy.env` (if used) out of version control.

## Notes

- **Costs:** Route 53 hosted zone monthly fee, domain renewal, S3 storage, CloudFront data transfer. Small personal sites are typically a few dollars per month plus domain registration.
- **www:** Apex and `www` both point to CloudFront; certificate includes both names.
- **State:** `infra/terraform.tfstate` is local by default and gitignored. For teams, use a remote backend (S3 + DynamoDB lock).
- **Bucket name:** If `terraform apply` fails because the bucket name is taken, pick another `site_bucket_name` in `terraform.tfvars`.
