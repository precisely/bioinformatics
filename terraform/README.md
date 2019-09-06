# Terraform configuration

## Requirements

### Terraform

Options:

1. [Official binary download](https://www.terraform.io/downloads.html) — install somewhere on your `PATH`
2. Homebrew: `brew install terraform`
3. Nix: Add `terraform_0_12` to your `default.nix`
4. Build from golang source: 😱


### AWS

Set up your credentials in `.aws/credentials`.

FIXME: Document this further.


## Getting started

1. `terraform init` — this should download the AWS plugin into the `.terraform` working directory.


## Spinning up instances

Need a variable to specify how many boxes to spin up.

`terraform apply -var '...=1'`
