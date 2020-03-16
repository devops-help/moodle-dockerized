# WIP: Moodle Docker Image 

This project creates a Docker image based on Debian Buster with Apache2 that includes all the necessary packages
and configurations to run Moodle with Apache2.

In addition to building the Docker image, a CloudFormation template is provided that creates the necessary
infrastructure in AWS for hosting on an EC2 instance and utilizing RDS for the Moodle database.

___

## Building the Moodle Docker Image
To build the Moodle Docker image Docker must be installed on your workstation.
See [Docker Engine overview](https://docs.docker.com/install/) for more info.

To build the Moodle Docker image simply run the following command in the root of this project:
```bash
./build-image
```

___

## Running Moodle using the Moodle Docker Image