#!/bin/bash -x

agentSendLogMessage "Installing Appd PYTHON-Agent."

/usr/share/venv/bin/pip install appdynamics

pyagent run -c <path_to_appdynamics_config_file> -- gunicorn -w 8 -b '0.0.0.0:9000' example.app:application
