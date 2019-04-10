#!/bin/bash

echo "198.169.195.125 dangerous2019031501233911.saas.appdynamics.com" >> /etc/hosts

sudo yum install java-1.8.0-openjdk-headless -y

sudo java -jar /opt/appd/mysql-agent/db-agent.jar
