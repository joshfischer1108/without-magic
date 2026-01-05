# Terraform AWS EC2 Node Sandbox

This topic provisions a single EC2 instance on AWS with Terraform and uses cloud-init to install:
- Node.js
- nginx
- a tiny Node HTTP server (systemd managed)

The point is not "best practice".
The point is to see the real moving pieces and learn how to debug them.

## What you will build

- EC2 instance in the default VPC/subnet
- Security group allowing SSH (22) and HTTP (80)
- Node server listening on 127.0.0.1:8080
- nginx reverse proxy on port 80 forwarding to the Node server

## What you will learn

- Terraform basics: plan, apply, state, outputs
- cloud-init: how bootstrapping actually happens
- systemd: how services run and restart
- nginx reverse proxy: how traffic gets routed
- Debugging: where failures show up and how to prove what is wrong

## Prerequisites

On your local machine:
- Terraform installed
- AWS credentials configured (via env vars or AWS CLI config)

For the simplest experience, use credentials with **AdministratorAccess**.
If you want to understand the actual permissions involved, a minimal IAM policy is documented below.

Verify AWS access is working as expected:

```bash
aws sts get-caller-identity
```

### Quick start

Run all commands from this folder.

### Generate SSH keypair
Make sure you have an SSH key pair locally. 
```bash
ssh-keygen -t ed25519 -f ./sandbox_key -N ""
```

### Terraform init/apply
Deploy infrastructure
```bash
terraform init
terraform apply -auto-approve
```

### Grab the IP of the created instance:
```bash
IP="$(terraform output -raw instance_public_ip)"
```

> The $IP variable will be reused in the following steps.

### Early inspection during startup

After `terraform apply` completes, the EC2 instance still needs time to finish bootstrapping.

During the first 1–3 minutes, you may see different behavior when hitting the public IP:

- `curl` fails to connect
- nginx returns the default “Welcome to nginx!” page
- eventually, the Node JSON response appears

This is expected.

Terraform only waits for the instance to exist.  
cloud-init continues running **after** Terraform finishes.

Do not assume failure just because HTTP does not work immediately.

To check progress, SSH into the instance and inspect cloud-init:

> At this point, the instance exists but the software stack may not be ready yet.
We SSH in early on purpose to observe what state the system is actually in while cloud-init is still running.

```bash
ssh -i ./sandbox_key ubuntu@"$IP"
sudo cloud-init status --long
```
> If cloud-init is still running, seeing connection failures or the default nginx page from outside is expected.

### Test via command line:
In a new local terminal, run
```bash
curl "http://$IP/"
```
A successful response should look like
```json
{
  "message": "Hello from Node on EC2 deployed by Terraform",
  "method": "GET",
  "path": "/",
  "headers": {
    "host": "34.229.217.27",
    "x-real-ip": "24.217.224.206",
    "x-forwarded-for": "24.217.224.206",
    "x-forwarded-proto": "http",
    "connection": "close",
    "user-agent": "curl/8.2.1",
    "accept": "*/*"
  },
  "time": "2026-01-05T00:03:49.474Z"
}    
```


### Check services:
In the terminal connected to the VM, run:
```bash
sudo systemctl status node-app --no-pager
sudo journalctl -u node-app -n 50 --no-pager
sudo nginx -t
```

### When something goes wrong

If Terraform succeeds but the server does not respond, debug one layer at a time.
### cloud-init
In the terminal connected to the VM, run:
```bash
sudo cloud-init status --long
sudo tail -n 200 /var/log/cloud-init-output.log
```


### Node service
In the terminal connected to the VM, run:
```bash
sudo systemctl status node-app --no-pager
sudo journalctl -u node-app -n 200 --no-pager
sudo ss -ltnp | grep 8080 || true
```


### nginx
In the terminal connected to the VM, run:
```bash
sudo nginx -t
sudo tail -n 200 /var/log/nginx/error.log
sudo tail -n 200 /var/log/nginx/access.log
```


### Local connectivity tests
In the terminal connected to the VM, run:
```bash
curl http://127.0.0.1:8080/
curl http://127.0.0.1/
```

### Interpretation of behavior:

* If port `8080` works, but port `80` fails, this is an nginx problem

* If port `80` works, but port `8080` fails, this is a Node problem

* If neither works, cloud-init or systemd failed

## Tear down

When finished, destroy the infrastructure to avoid ongoing costs:
In a local terminal, run
```bash
terraform destroy -auto-approve
```

## IAM permissions (Optional)

This topic creates and manages the following AWS resources:
- EC2 instances
- Security groups
- Key pairs
- Elastic IP association (optional)
- Reads an Ubuntu AMI ID from SSM Parameter Store

### Easiest option

Use credentials with **AdministratorAccess**.

This avoids IAM friction and keeps the focus on Terraform, cloud-init, and debugging.

### Minimal required permissions (optional)

If you do not want to use full admin access, the IAM user or role needs permission to:

- ec2:RunInstances
- ec2:TerminateInstances
- ec2:Describe*
- ec2:CreateSecurityGroup
- ec2:AuthorizeSecurityGroupIngress
- ec2:AuthorizeSecurityGroupEgress
- ec2:DeleteSecurityGroup
- ec2:CreateKeyPair
- ec2:DeleteKeyPair
- ec2:AssociateAddress
- ec2:DescribeAddresses
- ssm:GetParameter
- iam:PassRole (only if you add instance roles later)

You can grant these via a custom policy or a permissive EC2-focused managed policy.
