#!/bin/bash

sudo yum install java-1.8.0-openjdk-headless -y

sudo java -jar /opt/appd/mysql-agent/db-agent.jar
