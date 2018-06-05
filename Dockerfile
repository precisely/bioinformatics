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
CMD "/bin/bash"
