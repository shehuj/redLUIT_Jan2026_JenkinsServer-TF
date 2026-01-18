# Availability Zone and Instance Type Fix

## Problem

The deployment was failing with:

```
Error: creating EC2 Instance: operation error EC2: RunInstances,
https response error StatusCode: 400, RequestID: ...,
api error Unsupported: Your requested instance type (m5.xlarge) is not
supported in your requested Availability Zone (***e).
Please retry your request by not specifying an Availability Zone or
choosing ***a, ***b, ***c, ***d, ***f.
```

## Root Cause

1. **No AZs specified**: The VPC module wasn't explicitly specifying availability zones
2. **Random AZ selection**: AWS was randomly selecting AZs, sometimes picking one that doesn't support m5.xlarge
3. **Instance type availability**: Not all instance types are available in all AZs

## Solutions Applied

### Fix 1: Explicitly Specify Availability Zones

Updated `terraform/main.tf` to use a data source for available AZs:

```hcl
# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {
  source             = "./modules/vpc"
  name               = "jenkins-vpc"
  cidr_block         = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.3.0/24"]
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}
```

This ensures we use the first two available AZs (typically `us-east-1a` and `us-east-1b`), which have broader instance type support.

### Fix 2: Change Default Instance Type

Changed the default instance type from `m5.xlarge` to `t3.large`:

```hcl
variable "instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
  default     = "t3.large"  # Changed from m5.xlarge
}
```

**Why `t3.large`?**
- Available in all AZs
- More cost-effective
- Burstable performance (good for Jenkins workloads)
- Sufficient for most Jenkins use cases (2 vCPU, 8 GB RAM)

## Instance Type Recommendations

### For Small Teams (1-5 developers)
- **t3.medium** - 2 vCPU, 4 GB RAM
- **t3.large** - 2 vCPU, 8 GB RAM (default)

### For Medium Teams (5-20 developers)
- **t3.xlarge** - 4 vCPU, 16 GB RAM
- **m5.large** - 2 vCPU, 8 GB RAM

### For Large Teams (20+ developers)
- **m5.xlarge** - 4 vCPU, 16 GB RAM
- **m5.2xlarge** - 8 vCPU, 32 GB RAM

### Instance Type Availability by Region

Most AZs support:
- ✅ t2, t3 family (all AZs)
- ✅ m5.large, m5.2xlarge (most AZs)
- ⚠️ m5.xlarge (limited AZs - check before using)

## How to Override Instance Type

### Method 1: Terraform Variables File

Create `terraform/terraform.tfvars`:

```hcl
instance_type = "t3.xlarge"
```

### Method 2: Command Line

```bash
terraform plan -var="instance_type=t3.xlarge"
terraform apply -var="instance_type=t3.xlarge"
```

### Method 3: Environment Variable

```bash
export TF_VAR_instance_type="t3.xlarge"
terraform plan
terraform apply
```

### Method 4: GitHub Actions (for CI/CD)

Add to your repository secrets or workflow:

```yaml
env:
  TF_VAR_instance_type: "t3.xlarge"
```

Or add a new secret:
- Secret name: `INSTANCE_TYPE`
- Secret value: `t3.xlarge`

Then update the workflow to use it.

## How to Specify Availability Zones Manually

If you want to use specific AZs (e.g., for m5.xlarge), update `terraform/main.tf`:

```hcl
module "vpc" {
  source         = "./modules/vpc"
  name           = "jenkins-vpc"
  cidr_block     = "10.0.0.0/16"
  public_subnets = ["10.0.1.0/24", "10.0.3.0/24"]
  # Manually specify AZs that support your instance type
  availability_zones = ["us-east-1a", "us-east-1b"]
}
```

## Checking Instance Type Availability

### Using AWS CLI

```bash
# Check which AZs support m5.xlarge in us-east-1
aws ec2 describe-instance-type-offerings \
  --location-type availability-zone \
  --filters Name=instance-type,Values=m5.xlarge \
  --region us-east-1 \
  --query 'InstanceTypeOfferings[].Location' \
  --output table

# Output example:
# -----------------
# |   Location    |
# -----------------
# |  us-east-1a   |
# |  us-east-1b   |
# |  us-east-1c   |
# |  us-east-1d   |
# |  us-east-1f   |
# -----------------
```

### Using AWS Console

1. Go to EC2 → Launch Instance
2. Select instance type (e.g., m5.xlarge)
3. Check "Availability Zone" dropdown to see which AZs support it

## Troubleshooting

### Error: Instance type not supported in AZ

**Solution 1**: Use the fixes above (already applied)

**Solution 2**: Change to a more widely available instance type:
```bash
terraform apply -var="instance_type=t3.large"
```

**Solution 3**: Manually specify AZs that support your desired instance type

### Error: Not enough capacity

If you get "InsufficientInstanceCapacity":
- Try a different AZ
- Try a different instance type
- Wait and retry (capacity issues are often temporary)

### Checking Current Configuration

```bash
cd terraform

# See what AZs will be used
terraform plan | grep availability_zone

# See current instance type
terraform plan | grep instance_type
```

## Cost Comparison

Monthly costs (approximate, us-east-1, Linux, on-demand):

| Instance Type | vCPU | RAM   | Monthly Cost |
|---------------|------|-------|--------------|
| t3.medium     | 2    | 4 GB  | ~$30         |
| t3.large      | 2    | 8 GB  | ~$60         |
| t3.xlarge     | 4    | 16 GB | ~$120        |
| m5.large      | 2    | 8 GB  | ~$70         |
| m5.xlarge     | 4    | 16 GB | ~$140        |
| m5.2xlarge    | 8    | 32 GB | ~$280        |

**Recommendation**: Start with `t3.large` and scale up if needed.

## Apply the Fixes

To apply these fixes:

```bash
cd terraform

# Reinitialize (if needed)
terraform init

# Plan with new configuration
terraform plan

# Apply
terraform apply -auto-approve
```

Or commit and push for GitHub Actions:

```bash
git add terraform/main.tf terraform/variables.tf AVAILABILITY_ZONE_FIX.md
git commit -m "Fix availability zone and instance type issues

- Add data source for available AZs
- Explicitly specify AZs for VPC subnets
- Change default instance type to t3.large (more widely available)
- Add documentation for instance type selection"
git push
```

## Files Changed

- `terraform/main.tf` - Added AZ data source and explicit AZ selection
- `terraform/variables.tf` - Changed default instance type to t3.large
- `AVAILABILITY_ZONE_FIX.md` - This documentation

## Next Steps

1. Apply the Terraform changes (already done if you pushed to GitHub)
2. Monitor the deployment for success
3. Adjust instance type if needed based on your workload
4. Consider using Reserved Instances or Savings Plans for cost optimization
