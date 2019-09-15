# Terraform configuration

We use [Terraform](https://www.terraform.io/) to manage the bio research compute farm. This directory contains the necessary configuration files and supporting scripts.

Every compute farm user has a named directory. Unless stated otherwise, expect to execute commands to manage your own instances from your own directory.


## Requirements

### Software

Install the following software on your machine:
- `awscli` version 1.16.189 or later
- `terraform` version 0.12
- `jq`

All are available on macOS from Homebrew and Nix.


### AWS

Retrieve your keys from the [AWS console](https://biodev-precisely.signin.aws.amazon.com/console):
1. Log in.
2. Go to the [IAM Users](https://console.aws.amazon.com/iam/home?region=us-west-2#/users) panel.
3. Select your user name.
4. Select the "Security credentials" tab.
5. Click "Create access key".
6. Run `aws configure` and paste in the keys from the previous step when prompted to do so.

This should have set up your credentials in `~/.aws/credentials`.

You now need to make your AWS credentials obvious to Terraform. You have several options here:
1. If there's only one profile in `~/.aws/credentials`, that should be sufficient. 🤞
2. If you have multiple profiles, set the `AWS_PROFILE` environment variable appropriately.
3. You may also wish to explicitly set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables. Numerous options exist for dealing with this transparently, including [direnv](https://direnv.net/).


### SSH

You should generate a dedicated SSH key for use on the cluster. Use a good passphrase.

```
$ ssh-keygen -t rsa -f ~/.ssh/precisely_aws_biodev
```

You should then add it to your running SSH agent:

```
$ ssh-add ~/.ssh/precisely_aws_biodev
```

SSH is open on TCP port 6601 on the cluster (this helps prevent casual attacks by keeping standard port 22 closed and firewalled away). It might be helpful to configure your SSH defaults to avoid having to type all that out, by editing your `.ssh/config` file:

```
Host *.compute.amazonaws.com
  IdentityFile ~/.ssh/precisely_aws_biodev
  Port 6601
  User ubuntu
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
```

Note the disabled host key checking — not very secure, but helps with sanity on throw-away hosts like these.

**NB:** Change your personal `main.cf` file's `ssh_public_key_path` entry to point to the public key you intend to use (preferably the fresh one you just made). Commit this change back to the repository.


## Using the cluster

### Getting started

Go into your personal TF directory, and run `terraform init`. This should download all needed TF plugins into the `.terraform` working directory.

Look at your `main.cf` file. Much of it should be self-explanatory.


### Spinning up instances

_From your personal TF directory,_ run `terraform apply`. This will prepare a plan and prompt you for acknowledgement. Once the infrastructure is put together, it will take a little time for instances to actually become available for use (usually 1-2min).

To specify the number of machines to spin up, specify the `machine_count` parameter on the command line like this: `terraform apply -var=machine_count=3` (this will start a cluster of 3 node instances).

To change the amount of scratch space allocated to the instance, specify the `ebs_size_gb` parameter on the command line like this: `terraform apply -var=ebs_size_gb=3000` (this will allocate a 3TB EBS volume to each instance).

Note that if you already have instances running, `terraform apply` may have unexpected effects in terms of how it spins up more instances or shuts them down. It would be easiest to `terraform destroy` first, then `terraform apply` with whatever new parameters you like.

If you find yourself consistently using some parameter values, feel free to change your `main.cf` and commit the changes back to GitHub.


### Shutting down instances

_From your personal TF directory,_ run `terraform destroy` and acknowledge.

**NB:** For cost reasons, please remember to do this when you are not using the cluster! Remember to copy anything you want to save into your S3 data bucket (see below)!


### Listing instances

Run `ls-instances` script located in this directory. It will tell you everything you need to know about all running instances (including other people's), including their public DNS names and IP addresses.


### Logging in

To log into your own cluster nodes using the SSH key you configured above, SSH into the instance on port 6601 with the `ubuntu` user.

For your convenience, [Mosh](https://mosh.org/) and [tmux](https://github.com/tmux/tmux/wiki) are available on each node. Mosh will help you retain your connection while your laptop sleeps or changes networks. Tmux will help you retain remote terminal state, and should be used to run any long-standing tasks (as it makes your remote processes independent of your local terminal emulator). (GNU Screen is also available, bu tmux improves on it in most ways.)

To log into someone else's cluster node (i.e., into a node which does not already have your public key), you will need to transfer your key into the instance. To do this, you will need to know the instance's region, availability zone, and instance ID. The `ls-instances` script provides all this information. Then run the following locally (fill in the ellipses):

```
$ aws ec2-instance-connect send-ssh-public-key --region ... --availability-zone ... --instance-id ... --instance-os-user ubuntu --ssh-public-key file:///path/to/.ssh/precisely_aws_biodev.pub
```

After that, you have 60sec to connect to the instance, using SSH or Mosh normally, using that key.


### Data access

Each instance mounts an individual `/scratch` EBS volume. This volume is specific to the instance, and will be destroyed along with the instance.

Each instance also mounts `/data-s3`, which uses FUSE to mount the cluster region's S3 data bucket. Use this to share data and for all durable storage.

The following workflow should work:
- Copy data files from `/data-s3` into `/scratch`. Do not point to files in `/data-s3` directoy, as this will be slow and inefficient. Remember that `/data-s3` represents an S3 bucket.
- Work in `/scratch`. This should work fairly well: the EBS volume mounted here should be backed with an SSD. If IO feels too slow, we can experiment with higher-performance (and pricier) SSD options.
- Copy anything you want to save from `/scratch` back into `/data-s3`.

**NB:** Avoid copying data across regions in AWS, as it can be expensive. Your cluster should already be set up to point to an S3 bucket in the region closest to you.


### Adding software

You have root access to every instance using `sudo`. Keep in mind, however, that all instances are ephemeral, and will not retain the software you install on them after being destroyed (though they will survive a reboot). If you want something permanently installed on these nodes, we will do this by updating Ansible configurations and using Packer to build new AMIs (see the related sibling directories for more details).
