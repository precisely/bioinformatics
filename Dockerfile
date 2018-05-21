# Use an official Python runtime as a parent image
FROM python:2.7-stretch

# Set the working directory to /app
WORKDIR /app

# Copy the current directory contents into the container at /app
ADD . /app

# Install any needed packages specified in requirements.txt
#RUN make

## Install OS packages:
RUN apt-get update && apt-get install -y \
    bcftools \
    samtools \
    tabix

RUN pip install --trusted-host pypi.python.org .

# Define environment variable
#ENV NAME World

# Run app.py when the container launches
#CMD ["python", "app.py"]
ENTRYPOINT python convert23andme/convert23andme.py ${S3_RAW_DATA_BUCKET} ${GENOTYPE_RAW_FILENAME} data/human_g1k_v37.fasta.gz convert23andme/ucsc-gene-symbols-coords.txt.gz ${S3_BUCKET_GENETICS_VCF}
