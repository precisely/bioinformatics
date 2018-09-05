# Bioinformatics

This repository contains all software that requires knowledge of
bioinformatics software, databases, and methods. The goal is to
sequester the more detailed bioinformatic data handling in this repo,
so that other code repos can simply use this repo as a black box.


## Requirements

Docker must be installed and available.


## Installation

An easy mnemonic: run the various `docker/*` scripts in alphabetical order!

First, build the Docker image. The `docker/build.sh` script takes four parameters: mode, target image tag, and AWS profile (from `~/.aws/credentials`). Mode is either `link` or `build`. `link` is for development mode, and mounts a volume from the host to connect to the `/precisely/app` directory in the container.

```
./docker/build.sh link bio1-img dev-profile-precisely
```

Second, create a container. The `docker/create.sh` script takes three or four parameters: mode, image tag, container name, and (in link mode only) the application source path.

```
./docker/create.sh link bio1-img bio1 .
```

Third, start the container.

```
./docker/start.sh bio1
```

In development (link) mode, you can now connect to the container and use it:

```
./docker/tmux.sh bio1
```


## Running

This has become fairly complicated. It has two main entry points:

- `run-user-import.sh` imports initial data for a new user, including VCF conversion, imputation, and DynamoDB load
- `run-update.sh` updates call variants in DynamoDB when reports have new call variant needs


## Tests

The test suite is rather incomplete, but both entry points do have tests:

- `tests/run-user-import.sh`
- `tests/run-update.sh`

They run completely offline, and manage their own Minio environment, so do not run a separate Minio instance on port 9000 when running these tests.


## Pushing to ECR

The container should be pushed to Amazon's Elastic Container Registry (ECR). The repository we use is `dev/precisely-bioinformatics`. In spite of its name, it should be the same across all environments — it is merely housed in the `dev` account. Its URI is `416000760642.dkr.ecr.us-east-1.amazonaws.com/dev/precisely-bioinformatics`.

A good process of making a new image is this:

```
export ecruri=416000760642.dkr.ecr.us-east-1.amazonaws.com/dev/precisely-bioinformatics
export version=2018-09-04-rev4
docker/build.sh build ${ecruri}:${version} default
docker tag ${ecruri}:${version} ${ecruri}:latest
```

Then obtain a Docker login session for the ECR:

```
$(aws ecr get-login --no-include-email)
docker push ${ecruri}
```

Please note that it may be advantageous to do this on an EC2 instance, as it substantially speeds up the process of copying data into ECR.


## Remote access

The containers are remotely accessible by SSH. (For convenience, Mosh and tmux are also installed.) This enables remote debugging as well as exploratory work on fairly high-powered machines.

In order to use remote access, first upload an SSH _public_ key (_do not_ upload a private key from a public-key pair, _only_ upload the public key!) to a shared S3 bucket: `precisely-ssh-public-keys`. Please give it a unique and easily identifiable name, and do not touch anyone else's public key saved in there.

Then, when you launch a container, you need to use a script especially set up to enable SSH on it: `run-remote-access.sh`. This script supports two modes of operation: purely enabling remote access without running extra tasks, and running tasks while keeping remote access available. In the former case, the container will be available for several minutes before exiting and stopping itself _or_ as long as a file called `/precisely/app/KEEP-RUNNING` exists (just `touch` it to keep the container alive indefinitely, and delete it to have the container eventually turn itself off). In the latter case, the container will run a task normally, but will keep an SSH daemon available — importantly, the container will unceremoniously terminate once the task completes.

To launch a container which does nothing more than makes itself available and waits for connections:

```
aws ecs run-task \
  --cluster cv-BioinformaticsECSCluster \
  --task-definition cv-BioinformaticsECSTask:5 \
  --count 1 \
  --launch-type FARGATE \
  --network-configuration $'{
  "awsvpcConfiguration": {
    "subnets": ["subnet-050b917dbfeaf43ad"],
    "securityGroups": ["sg-0ca9e7b2d39e79bd6"],
    "assignPublicIp": "ENABLED"
  }
}' \
  --overrides $'{
  "containerOverrides": [
    {
      "name": "cv-BioinformaticsECSContainer",
      "command": ["/precisely/app/run-remote-access.sh", "--keep-running=true"]
    }
  ]
}'
```

Note that you may need to adjust the `subnets` and `securityGroups` IDs to match your environment, not to mention the cluster, task, and container names!

To connect, look up the public IP of the container, and SSH (or Mosh) in normally as the `docker` user. Use port 6601.

To launch a container which runs a task with remote access available:

```
aws ecs run-task \
  --cluster cv-BioinformaticsECSCluster \
  --task-definition cv-BioinformaticsECSTask:5 \
  --count 1 \
  --launch-type FARGATE \
  --network-configuration $'{
  "awsvpcConfiguration": {
    "subnets": ["subnet-050b917dbfeaf43ad"],
    "securityGroups": ["sg-0ca9e7b2d39e79bd6"],
    "assignPublicIp": "ENABLED"
  }
}' \
  --overrides $'{
  "containerOverrides": [
    {
      "name": "cv-BioinformaticsECSContainer",
      "command": ["/bin/bash", "-c", "/precisely/app/run-remote-access.sh && e/precisely/app/run-user-import.sh --data-source=23andme --upload-path=genome_Andrew_Beeler_Full_20160320135452.txt --user-id=abeeler9 --stage=cv --test-mock-vcf=false --test-mock-lambda=false --cleanup-after=true"]
    }
  ]
}'
```

Note the form of the command: it uses the Docker exec form to spawn a shell which then uses the `&&` operator to start SSH _and_ execute another command. As of this writing, this is the only reasonable way to make Docker kick off multiple processes.


## Reference information

### 23andMe's tab-delimited raw data format

- 23andMe's data format documentation: https://customercare.23andme.com/hc/en-us/articles/115004459928-Raw-Data-Technical-Details
- http://fileformats.archiveteam.org/wiki/23andMe


### Obtaining 23andMe example data files for testing

- Source of publicly-available 23andMe datasets for testing: https://my.pgp-hms.org/public_genetic_data?data_type=23andMe


### Building the Compressed Reference Human Genome for bcftools

- Obtain the 1k Genomes reference human genome


### Building the Gene Coordinates BED File

- This is checked in as:
  convert23andme/ucsc-gene-symbols-coords.txt.gz
- This will only need to be updated if we need to support a human
  genome build other than 37.
- BED file obtained from the UCSC Genome Browser (see below)
- Idea of how to annotate the variants with gene names from here: https://www.biostars.org/p/122690/
- In the future, this should be automated using the cruzdb Python package


#### Generating the Gene Coordinate BED file using the UCSC Genome Browser

Go to UCSC Genome Browser page: https://genome.ucsc.edu/cgi-bin/hgTables

Select the following form options:
- clade: Mammal
- genome: Human
- assembly: "Feb. 2009 (GRCh37/hg19)"
- group: "Genes and Gene Predictions"
- track: "UCSC Genes"
- output format: "selected fields from primary and related tables

Leave everything blank or default.

Click on "get output"

On the following page, you will get a chance to select specific
columns from the hg19.knownGene and hg19.kgXref tables. Select the
following:
kg19.knownGene:
- name
- chrom
- txStart
- txEnd

hg19.kgXref:
- geneSymbol

Click on "get output" button below the hg19.knownGene listing.

Once downloaded, remove the first comment line from the file, and call
the file `ucsc-gene-names.txt`.


#### Final processing of BED File

Post-processing of the BED file:

```
$ awk -F'\t' 'BEGIN{ OFS="\t"} \
NR!=1 { gsub("chr","",$2); if($2 == "M") $2 = "MT"; print $2, $4, $5, $7  }' \
ucsc-gene-names.txt \
| sort -k1,1 -k2,2n \
| bgzip > ucsc-gene-symbols-coords.txt.gz
```

Use Tabix to index the BGzip'ed file:

```
$ tabix -p bed ucsc-gene-symbols-coords.txt.gz
```


### Backgroup VCF File Manipulation Documentation

- BCFtools documentation: https://samtools.github.io/bcftools/bcftools.html
- Using BCFtools to convert 23andMe to VCF: https://samtools.github.io/bcftools/howtos/convert.html
- Example using BCFtools to annotate variants with gene information: https://www.biostars.org/p/122690/
- Docs for PySam: http://pysam.readthedocs.io/en/stable/usage.html#working-with-vcf-bcf-formatted-files
