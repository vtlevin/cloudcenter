#!/bin/bash

echo "198.169.195.125 dangerous2019031501233911.saas.appdynamics.com" >> /etc/hosts

sudo java -jar /opt/appd/mysql/db-agent.jar
