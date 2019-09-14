# Terraform configuration

## Requirements

### Terraform

Options:

1. [Official binary download](https://www.terraform.io/downloads.html) — install somewhere on your `PATH`
2. Homebrew: `brew install terraform`
3. Nix: Add `terraform_0_12` to your `default.nix`
4. Build from golang source: 😱


### AWS

#### Credentials

Retrieve your keys from the [AWS console](https://biodev-precisely.signin.aws.amazon.com/console):
1. Log in.
2. Go to the [IAM Users](https://console.aws.amazon.com/iam/home?region=us-west-2#/users) panel.
3. Select your user name.
4. Select the "Security credentials" tab.
5. Click "Create access key".
6. Run `aws configure` and paste in the keys from the previous step.

This should have set up your credentials in `~/.aws/credentials`.


#### Utilities

Install [AWS Command Line Interface (`awscli`)](https://aws.amazon.com/cli/), version 1.16.189 or later highly recommended. Options:

1. `pip install awscli`
2. Homebrew: `brew install awscli`
3. Nix: Add `awscli` to your `default.nix`


### SSH

You should generate a dedicated key for use on the cluster. Use a good passphrase.

```
$ ssh-keygen -t rsa -f ~/.ssh/precisely_aws_biodev
```

You should then add it to your running SSH agent:

```
$ ssh-add ~/.ssh/precisely_aws_biodev
```

SSH is open on TCP port 6601 on the cluster (this helps prevent casual attacks by keeping standard port 22 closed and firewalled away). [Mosh](https://mosh.org/) is also available.

It might be helpful to configure your SSH defaults to avoid having to type all that out, by editing your `.ssh/config` file:

```
Host *.compute.amazonaws.com
  IdentityFile ~/.ssh/precisely_aws_biodev
  Port 6601
  User ubuntu
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
```

Note the disabled host key checking — not very secure, but helps with sanity on throw-away hosts like these.


## Getting started

1. `terraform init` — this should download the AWS plugin into the `.terraform` working directory.


### Spinning up instances

Need a variable to specify how many boxes to spin up.

`terraform apply -var '...=1'`


### S3 data stores
