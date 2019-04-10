#!/bin/bash

# This script requires privilege users to execute.
#
# If pre-check is not skipped, checks prerequisites for installing and running
# tet-sensor on Linux hosts.
#
# If all prerequisites are met and installation succeeds, the script exits
# with 0. Otherwise it terminates with a non-zero exit code for the first error
# faced during execution.
#
# The failure message is written to a logfile if passed, stdout otherwise.
# Pre-check can skip IPv6 test by passing the --skip-ipv6 flag.
#
# Exit code - Reason:
# 255 - root was not used to execute the script
# 240 - invalid parameters are detected
# 239 - installation failed
#   1 - pre-check: IPv6 is not configured or disabled
#   2 - pre-check: su is not operational
#   3 - pre-check: curl is missing or not from rpmdb
#   4 - pre-check: curl/libcurl compatibility test failed
#   5 - pre-check: /tmp is not writable
#   6 - pre-check: /usr/local/tet cannot be created
#   7 - pre-check: ip6tables missing or needed kernel modules not loadable
#   8 - pre-check: unzip is missing

# Do not trust system's PATH
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SCRIPT_VERSION=1.0
LOG_FILE=
SKIP_IPV6=1
DO_PRECHECK=1
NO_INSTALL=0
DISTRO=
VERSION=
SENSOR_VERSION=
LIST_VERSION="False"
# Sensor type is chosen by users on UI
SENSOR_TYPE="enforcer"

function print_usage {
  echo "Usage: $0 [--skip-pre-check] [--no-install] [--logfile=<filename>] [--proxy=<proxy_string>] [--skip-ipv6-check] [--help] [--version] [--sensorVersion] [--ls]"
  echo "  --skip-pre-check: skip pre-installation check (on by default)"
  echo "  --no-install: will not download and install sensor package onto the system"
  echo "  --logfile <filename>: write the log to the file specified by <filename>"
  echo "  --skip-ipv6-check: skip IPv6 test"
  echo "  --help: print this usage"
  echo "  --version: print current script's version"
  echo "  --sensor-version <versionInfo>: decide sensor's version; e.g.: '--sensor-version=3.1.1.53.devel'; will download the latest version by default"
  echo "  --ls: list all available sensor versions for your system; will not download any package"
}

function print_version {
  echo "Installation script for Cisco Tetration Agent (Version: $SCRIPT_VERSION)."
  echo "Copyright (c) 2018 Cisco Systems, Inc. All Rights Reserved."
}

function log {
  if [ -z $LOG_FILE ]; then
    echo $@
  else
    echo $@ >> $LOG_FILE
  fi
}

function pre_check {
  log ""
  log "### Testing tet-sensor prerequisites on host \"$(hostname -s)\" ($(date))"
  log "### Script version: $SCRIPT_VERSION"

  # Used for detecting when running on Ubuntu
  DISTRO=
  if [ -e /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$NAME
  fi

  # detect whether IPv6 is enabled
  if [ $SENSOR_TYPE == "enforcer" ] && [ $SKIP_IPV6 -eq 0 ]; then
    log "Detecting IPv6"
    if [ ! -e /proc/sys/net/ipv6 ]; then log "Error: IPv6 is not configured"; return 1; fi
    v=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)
    ret=$?
    if [ $ret -ne 0 ]; then log "Error: Failed to verify if IPv6 is enabled: ($ret)"; return 1; fi
    if [ $v = 1 ]; then log "Error: IPv6 is disabled"; return 1; fi
    which ip6tables &> /dev/null
    if [ $? -ne 0 ]; then log "Error: ip6tables command is missing"; return 7; fi
    ip6tables -nvL &> /dev/null
    if [ $? -ne 0 ]; then log "Error: ip6tables command is not functional (check kernel modules)"; return 7; fi
  fi

  log "Testing su"
  # detect whether su could be invoked
  (su nobody -s /bin/bash -c date >> /dev/null) &
  PID=$!
  sleep 3; kill -9 $PID 2> /dev/null
  wait $PID
  if [ $? -ne 0 ]; then
    log "Error: su failed to return within specified time"
    return 2
  fi

  log "Detecting curl/libcurl version"
  NO_CURL=0
  CURL_VER_REL=$(rpm -q --qf "%{version}-%{release}" curl)
  if [ $? -ne 0 ]; then
    which curl &> /dev/null
    if [ $? -ne 0 ]; then
      log "Error: No curl installed"
      return 3
    fi
    if [ "$DISTRO" != Ubuntu ]; then
      log "Error: curl present but not in rpmdb"
      return 3
    fi
    NO_CURL=1
  fi

  if [ $NO_CURL -eq 0 ]; then
    log "Running curl/libcurl compatibility test"
    NO_LIBCURL=0
    LIBCURL=$(rpm -q libcurl) || LIBCURL=$(rpm -q libcurl4)
    [ $? -ne 0 ] && log "Error: No libcurl installed?" && NO_LIBCURL=1

    if [ $NO_LIBCURL -ne 1 ]; then
      LIBCURL_VER=$(rpm -q libcurl-$CURL_VER_REL) || LIBCURL_VER=$(rpm -q libcurl4-$CURL_VER_REL)
      if [ $? -ne 0 ] || [ "$LIBCURL_VER" != "$LIBCURL" ]; then
        log "Error: curl and libcurl version not matching. $LIBCURL vs $LIBCURL_VER. This could be an issue."
        return 4
      fi
      log "$CURL_VER_REL"
      log "$LIBCURL_VER"
    fi
  fi

  log "Testing /tmp/"
  RAND_NUM=$RANDOM
  su nobody -s /bin/bash -c "echo $RAND_NUM > /tmp/$RAND_NUM"
  ret=$?
  if [ $ret -ne 0 ]; then
    log "Error: Cannot creating file in /tmp/: ($ret)"
    return 5
  fi
  rm -rf /tmp/$RAND_NUM

  log "Testing /usr/local/tet/"
  if [ ! -e  /usr/local/tet/ ]; then
    mkdir -p /usr/local/tet
    ret=$?
    if [ $ret -ne 0 ]; then
      log "Error: Can not create /usr/local/tet: ($ret)"
      return 6
    fi
    rm -rf /usr/local/tet
  else
    # check the expected processes are running
    t=$(ps -e | grep tet-engine)
    te1=$(echo $t | awk '{ print $4 }')
    te2=$(echo $t | awk '{ print $8 }')
    t=$(ps -e | grep tet-sensor)
    ts1=$(echo $t | awk '{ print $4 }')
    ts2=$(echo $t | awk '{ print $8 }')
    if [ "$te1" = "tet-engine" ] && [ "$te2" = "tet-engine" ] && [ "$ts1" = "tet-sensor" ] && [ "$ts2" = "tet-sensor" ] ; then
      log "/usr/local/tet already present. Expected tet-engine and tet-sensor instances found"
    else
      log "/usr/local/tet already present. Expected tet-engine and tet-sensor instances NOT found"
    fi
  fi

  # Check unzip tool
  log "Testing unzip"
  which unzip &> /dev/null
  if [ $? -ne 0 ]; then
    log "Error: No unzip installed"
    return 8
  fi

  log "### Pre-check Passed"
  return 0
}

function check_host_version {
   # Check for redhat/centos
   # In CentOS, string looks like this: "CentOS release 6.x (Final)"
   # But in RHEL, string looks like this: "Red Hat Enterprise Linux Server release 6.x (Santiago)"
   # So we convert RHEL string to "RedHatEnterpriseServer release 6.x (Santiago)", and then
   # grab $1 and $3 parameters to form the platform string.
   if [ -e /etc/redhat-release ] ; then
      RH_RELEASE=$(cat /etc/redhat-release)
      RH_RELEASE=${RH_RELEASE/Red Hat Enterprise Linux Server/RedHatEnterpriseServer}
      RH_RELEASE=${RH_RELEASE/CentOS Linux/CentOS}
      DISTRO=$(echo $RH_RELEASE | awk '{print $1}')
      VERSION=$(echo $RH_RELEASE | awk '{print $3}')
      case "$VERSION" in
        5.*)
          SENSOR_TYPE="sensor"
          ;;
        7.*)
          VERSION=$(echo $VERSION|sed 's/\./ /g' | awk '{print $1"."$2}')
          ;;
      esac
      return 0
   fi

   # Ubuntu may have this
   if [ -e /etc/os-release ] ; then
      . /etc/os-release
      DISTRO=$NAME
      VERSION=$VERSION_ID
      case "$DISTRO" in
        SLES)
          DISTRO="SUSELinuxEnterpriseServer"
          ;;
      esac
      return 0
   fi

   # SLES 11.2 and 11.3 don't have os-release
   if [ -e /etc/SuSE-release ] ; then
       DISTRO=$(cat /etc/SuSE-release | head -1 |awk '{print $1$2$3$4}')
       VERSION=$(cat /etc/SuSE-release | grep 'VERSION' | awk -F "= " '/VERSION/ {print $2}')
       PATCHLEVEL=$(cat /etc/SuSE-release | grep 'PATCHLEVEL' | awk -F "= " '/PATCHLEVEL/ {print $2}')
       VERSION=$VERSION.$PATCHLEVEL
       return 0
   fi

   # Unknown OS/Version
   DISTRO="Unknown"
   VERSION=`uname -a`
   return 1
}

function list_available_versions {
  
  # Create a random folder in /tmp, assuming it's writable (pre-check done)
  TMP_DIR=$(mktemp -d /tmp/tet.XXXXXX)
  log "Created temporary directory $TMP_DIR"
  cd $TMP_DIR

cat << EOF > ta_sensor_ca.pem
-----BEGIN CERTIFICATE-----
MIIF4TCCA8mgAwIBAgIJALNYYzC/WVg1MA0GCSqGSIb3DQEBCwUAMH8xCzAJBgNV
BAYTAlVTMQswCQYDVQQIDAJDQTERMA8GA1UEBwwIU2FuIEpvc2UxHDAaBgNVBAoM
E0Npc2NvIFN5c3RlbXMsIEluYy4xHDAaBgNVBAsME1RldHJhdGlvbiBBbmFseXRp
Y3MxFDASBgNVBAMMC0N1c3RvbWVyIENBMB4XDTE4MTAxMDE4NTMyN1oXDTI4MTAw
NzE4NTMyN1owfzELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAkNBMREwDwYDVQQHDAhT
YW4gSm9zZTEcMBoGA1UECgwTQ2lzY28gU3lzdGVtcywgSW5jLjEcMBoGA1UECwwT
VGV0cmF0aW9uIEFuYWx5dGljczEUMBIGA1UEAwwLQ3VzdG9tZXIgQ0EwggIiMA0G
CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCnKSTnwA6oGUFxYKP4wu2N41ywUlPt
v3l2O9fC/vYc8qLfK/Td09QorhcOy5s41n13deLGvoD2+Ns//ec6zID2c22A0RT+
pkq8kCU+uTj3BzXUdXVJ7auSpuF64YhSeuChtwaplOOeW9STLtwjYb7GDYZLNJPa
c+I+CPc2Bv2KH/M3UJSZizXaA4G246CDulwnSVh0GfnBoJQflTlcr0vvT/hQeb4Y
5CjH6Rrqx2rwrRGFZv7i/UCCWIUv4v47cg3Xx2RdOmMFJ1eO8+zVqwXbwU1nr0Cd
wIVNAfhByOTwyjdMq/I1wjM28Gy0zfcqlM8Fjv8FOxoeeAjETMF3JjohEc8PTsca
z6GljNYbHkOc4aVM4P4iQCepCmRuCMFT0hNJ6VK0Y8mM4ubhwDbQWDqILUs6EvHJ
cyulIVO3StlixB0Te8cXs9Dft+vYhCp6nj63M9s5/xkp59UBvXyg5RghGLwN8OWD
FRY581AGPV7m7rxMXP1tFzJSIxIjWu4ZDwACrw9dCYvSEdDJHmy/OtF3EKreOmaO
6nsymcIOFrQ4qoCMlFoMMgKLS1XJ2w2XnyPhCI4MNPhQKHf6C3so1ks/P1LGE3Xm
3xkaluFDuto2UlMK+JUHXTFVlIDCgnMozwL8FACkuZcBSopXMhOY1gAX/L5wKJl0
mAnIYrFv/Q2EcwIDAQABo2AwXjAdBgNVHQ4EFgQUa/wlMu5Ij6tlZz+m6a0sbhLj
B2MwHwYDVR0jBBgwFoAUa/wlMu5Ij6tlZz+m6a0sbhLjB2MwDwYDVR0TAQH/BAUw
AwEB/zALBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggIBACVviG9ADyvNcMYx
TNnCeSLRTVqdVlpqnqaGFagDP1CIlBFUHIpc06DFbvi+OyDaCnjdgenYkV2ASHmQ
Un7Jiowy6G21I2LdxGzfsXMXO3jCvYgAqfhHWgUKKH2/aFFLX2Azlpcv4XpqCurk
+FKOYkc7AjTCR6yNMms5SEDBN7uDWVO0twcsggj6N+PHianL0f6Lsbyv7+psqcqp
ctiauSn2bzbzo8mzJ9ywxF/+QiCkHt96gxdPw70GCYMOf3R6C15+aVMxoWL42D1a
LkjLLyGdYgueFkGJHTu6wxtjVKhdSWHberuJfwYw3EG/SmTLGkMFq2Q/fbNZ/WhC
oRCYyE4a935+Qk8cBvlj8FpRC8cwXeOz5vbQK/1uGV/EwuLQF4RGKW27cKP3JqPn
7wsmL2hoPVqLkder53F4Pylfbm9uHnLPYR8PTL/QS+Ob/v4otnxfZTgvMcX99Zlw
7ONV1L0LJPjB5CUJA336vnxR82kLieB0PGCatFtyNbzzu/SxwAarcEIe2nSH9oDz
/e7iZIoJ3aFVxSpzPnogrRuLjCizKfzJ5/+RvWgtNPdg+vTntM2JkJ2L1b7I0dJC
xy4+XhaZivR0f3IUvG8p0XiLIGVY7uD/M2K/GVk/0qJYTymlKpy1HLbQyxQdapv8
8ZBhOY6hC6cPiHCy04P3pE5aLwGf
-----END CERTIFICATE-----

EOF

  # set package type info
  PKG_TYPE="sensor_w_cfg"

  check_host_version
  [ $? -ne 0 ] && echo "Error: Unsupported platform $DISTRO-$VERSION" && return 1
  
  ARCH=$(uname -m)
  METHOD="GET"
  URI="/openapi/v1/sw_assets/download?pkg_type=$PKG_TYPE\&platform=$DISTRO-$VERSION\&arch=$ARCH\&list_version=$LIST_VERSION"
  URI_NO_ESC="/openapi/v1/sw_assets/download?pkg_type=$PKG_TYPE&platform=$DISTRO-$VERSION&arch=$ARCH&list_version=$LIST_VERSION"
  CHK_SUM=""
  CONTENT_TYPE=""
  TS=$(date -u "+%Y-%m-%dT%H:%M:%S+0000")
  HOST="https://64.100.1.213"
  API_KEY=3b00ca87248045c1a4dd80b443e16cc4
  API_SECRET=e045cf75a258653e60fc014a83a6a2feb8f63191

  # Calculate the signature based on the params
  # <httpMethod>\n<requestURI>\n<chksumOfBody>\n<ContentType>\n<TimestampHeader>
  
  MSG=$(echo -n -e "$METHOD\n$URI_NO_ESC\n$CHK_SUM\n$CONTENT_TYPE\n$TS\n")
  SIG=$(echo "$MSG"| openssl dgst -sha256 -hmac $API_SECRET -binary | openssl enc -base64)
  REQ=$(echo -n "curl --cacert ta_sensor_ca.pem $HOST$URI -w '%{http_code}' -H 'Timestamp: $TS' -H 'Id: $API_KEY' -H 'Authorization: $SIG'")
  RESP=$(sh -c "$REQ")
  STATUS=${RESP##*$'\n'}
  if [ $STATUS -eq 200 ] ; then
    RESP_INFO=$(echo "$RESP" | sed '$d')
    echo -e "Available version:\n$RESP_INFO"
    log "Cleaning temporary files"
    rm -rf $TMP_DIR
    return 0
  elif [ $STATUS -eq 400 ] ; then
    echo "Bad request; please check package type info"
  else
    echo "Unexpected error: $STATUS"
  fi
  log "Cleaning temporary files"
  rm -rf $TMP_DIR
  return 1
}

function perform_install {
  log ""
  log "### Installing tet-sensor on host \"$(hostname -s)\" ($(date))"

  # Check if old binaries already exist
  if [ -e /usr/local/tet/tet-sensor ] || [ -e /usr/local/tet/tet-enforcer ] ; then
    log "Error: Sensor binaries already exist, cannot proceed"
    return 1
  fi

  # Create a random folder in /tmp, assuming it's writable (pre-check done)
  TMP_DIR=$(mktemp -d /tmp/tet.XXXXXX)
  log "Created temporary directory $TMP_DIR"
  EXEC_DIR=$(pwd)
  log "Execution directory $EXEC_DIR"
  cd $TMP_DIR

cat << EOF > tet.user.cfg
ACTIVATION_KEY=
HTTPS_PROXY=
EOF

cat << EOF > ta_sensor_ca.pem
-----BEGIN CERTIFICATE-----
MIIF4TCCA8mgAwIBAgIJALNYYzC/WVg1MA0GCSqGSIb3DQEBCwUAMH8xCzAJBgNV
BAYTAlVTMQswCQYDVQQIDAJDQTERMA8GA1UEBwwIU2FuIEpvc2UxHDAaBgNVBAoM
E0Npc2NvIFN5c3RlbXMsIEluYy4xHDAaBgNVBAsME1RldHJhdGlvbiBBbmFseXRp
Y3MxFDASBgNVBAMMC0N1c3RvbWVyIENBMB4XDTE4MTAxMDE4NTMyN1oXDTI4MTAw
NzE4NTMyN1owfzELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAkNBMREwDwYDVQQHDAhT
YW4gSm9zZTEcMBoGA1UECgwTQ2lzY28gU3lzdGVtcywgSW5jLjEcMBoGA1UECwwT
VGV0cmF0aW9uIEFuYWx5dGljczEUMBIGA1UEAwwLQ3VzdG9tZXIgQ0EwggIiMA0G
CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCnKSTnwA6oGUFxYKP4wu2N41ywUlPt
v3l2O9fC/vYc8qLfK/Td09QorhcOy5s41n13deLGvoD2+Ns//ec6zID2c22A0RT+
pkq8kCU+uTj3BzXUdXVJ7auSpuF64YhSeuChtwaplOOeW9STLtwjYb7GDYZLNJPa
c+I+CPc2Bv2KH/M3UJSZizXaA4G246CDulwnSVh0GfnBoJQflTlcr0vvT/hQeb4Y
5CjH6Rrqx2rwrRGFZv7i/UCCWIUv4v47cg3Xx2RdOmMFJ1eO8+zVqwXbwU1nr0Cd
wIVNAfhByOTwyjdMq/I1wjM28Gy0zfcqlM8Fjv8FOxoeeAjETMF3JjohEc8PTsca
z6GljNYbHkOc4aVM4P4iQCepCmRuCMFT0hNJ6VK0Y8mM4ubhwDbQWDqILUs6EvHJ
cyulIVO3StlixB0Te8cXs9Dft+vYhCp6nj63M9s5/xkp59UBvXyg5RghGLwN8OWD
FRY581AGPV7m7rxMXP1tFzJSIxIjWu4ZDwACrw9dCYvSEdDJHmy/OtF3EKreOmaO
6nsymcIOFrQ4qoCMlFoMMgKLS1XJ2w2XnyPhCI4MNPhQKHf6C3so1ks/P1LGE3Xm
3xkaluFDuto2UlMK+JUHXTFVlIDCgnMozwL8FACkuZcBSopXMhOY1gAX/L5wKJl0
mAnIYrFv/Q2EcwIDAQABo2AwXjAdBgNVHQ4EFgQUa/wlMu5Ij6tlZz+m6a0sbhLj
B2MwHwYDVR0jBBgwFoAUa/wlMu5Ij6tlZz+m6a0sbhLjB2MwDwYDVR0TAQH/BAUw
AwEB/zALBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggIBACVviG9ADyvNcMYx
TNnCeSLRTVqdVlpqnqaGFagDP1CIlBFUHIpc06DFbvi+OyDaCnjdgenYkV2ASHmQ
Un7Jiowy6G21I2LdxGzfsXMXO3jCvYgAqfhHWgUKKH2/aFFLX2Azlpcv4XpqCurk
+FKOYkc7AjTCR6yNMms5SEDBN7uDWVO0twcsggj6N+PHianL0f6Lsbyv7+psqcqp
ctiauSn2bzbzo8mzJ9ywxF/+QiCkHt96gxdPw70GCYMOf3R6C15+aVMxoWL42D1a
LkjLLyGdYgueFkGJHTu6wxtjVKhdSWHberuJfwYw3EG/SmTLGkMFq2Q/fbNZ/WhC
oRCYyE4a935+Qk8cBvlj8FpRC8cwXeOz5vbQK/1uGV/EwuLQF4RGKW27cKP3JqPn
7wsmL2hoPVqLkder53F4Pylfbm9uHnLPYR8PTL/QS+Ob/v4otnxfZTgvMcX99Zlw
7ONV1L0LJPjB5CUJA336vnxR82kLieB0PGCatFtyNbzzu/SxwAarcEIe2nSH9oDz
/e7iZIoJ3aFVxSpzPnogrRuLjCizKfzJ5/+RvWgtNPdg+vTntM2JkJ2L1b7I0dJC
xy4+XhaZivR0f3IUvG8p0XiLIGVY7uD/M2K/GVk/0qJYTymlKpy1HLbQyxQdapv8
8ZBhOY6hC6cPiHCy04P3pE5aLwGf
-----END CERTIFICATE-----

EOF

  # Decide which key to used for validation of whether the package is properly signed.
  # If the key already exist we won't overwrite it.
  if [ ! -e sensor-gpg.key ] ; then
      DEV_SENSOR=false
      if [ "$DEV_SENSOR" = true ] ; then

          # This is the dev public sensor signing key.
cat << EOF > sensor-gpg.key
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.11 (GNU/Linux)

mQENBFbECa0BCADQV84MekXnIZB7lKBBn+Hfq6MTgl/0SIZCSQaiznXZ1oKwcIIq
izU4kE/rY8XoOZdIataFcMYycH4U5NkAx11DdvSH6hrIG9BmIlcZKw92oE/YLgZP
xCUug2UDAI8QLZawPBttwal/LU9oeuKHeF8K4iIlmq3Z38KLhGPsD6Tvhl2/bAez
xyp2cFRrKcvYdaKIA6aBHHLSpfo+wXUXHtI+vyBd6Hp+5BrqbwZvFT7bnD7csOAx
hWs9MX2wm4ANmlTWed00pEMjS5iOTwzPeAlQlyleLXEjtXzoCEuq+9ufEirvDVqb
JQeL/pxGYN80w625h4EOJ92/L7XTVUwlPJnxABEBAAG0MlNlbnNvciBEZXYgS2V5
IDxzZW5zb3ItZGV2QHRldHJhdGlvbmFuYWx5dGljcy5jb20+iQE+BBMBAgAoBQJW
xAmtAhsDBQkJZgGABgsJCAcDAgYVCAIJCgsEFgIDAQIeAQIXgAAKCRAlscFprx/C
b3YHB/90K7lK5wwo+H+EccA9JQ19xnFK78M8UGgGj6QT2rcf1NJgTD2FXlpIEVGZ
yf3UBhyTdhlM0RsyIE4S65XrorgulM4Hzy94/y0kSRBJfnnFBKI1uNJVRupY4Y/9
WJrV7y1JN0ubFpjBdHKrKqq9822XSLVF7F3ZzLmwRMMLtFDi+leHnFCZ0OY4z7Yv
wd1XGZNhaApryQUZbjSIOgiTQCvTN+P0EEo73sm0rUxnpvQapzbWUnAWAoCI4vbb
q57mUGQZ7tYEeooEiTjk9xyU8PA0cRVarMbMNoXZtvu+xW0ipYRx6zh7Od5enGFP
LxrgudPMvK79Z22e+SZ7GiwFO5ON
=jaK+
-----END PGP PUBLIC KEY BLOCK-----
EOF

      else

          # This is the prod public sensor signing key.
cat << EOF > sensor-gpg.key
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v2.0.14 (GNU/Linux)

mQENBFYVKHUBCACv6ZaWxa0/VptX9YJvnLEZvPSCV7idmbi0K911bYCY7OTpCzl1
tfDJO1SLiLeyT88Rq8PYzjY3fZqtdn3l9HTGkKqLbHOFV3qWgCau2I3SXEiIIis+
TL50zTXnF05kUKdYWXIjWgM8oD8GHQA+oWgyKWFZgA32rmcwIshndrP406U1b31N
sdo0AMbfa2nY5CHj31Cyg2/t53NOOCcVasCZ1Jx5MEkNmyNAUDtG1HbeTCjhG+Qn
ul4ugICRKiPtGsGlAhV+cI8sX9GUgepp0AzCaCEVmudwIuAT5+s0NGXqKaLTqBPV
t1fWk4U9Nw1BKd/AtFTy9u1uju0TVsOwO6XrABEBAAG0NlRldHJhdGlvbiBTZW5z
b3IgPHNlbnNvci1hZG1pbkB0ZXRyYXRpb25hbmFseXRpY3MuY29tPokBPgQTAQIA
KAUCVhUodQIbAwUJEswDAAYLCQgHAwIGFQgCCQoLBBYCAwECHgECF4AACgkQkuMZ
7s+YSL4Q1AgAmav2IsXsUgXu5rzBeTXD+0kuwX36MJg8g4/4nwxla2bQMmhzCuC8
436FX5h3eR3Mipviah3xmw8yolfYmBNmINFfl4mAbXa8WAPatdD0fL1AXdRGre1c
EI9kUIR0WfUIVURkZJPNsdn6Jass3ZUhw51v9o0gEi5GPFtHCXtvZR2BIwZ89mUK
0qS1pL5w0zezZAyB7A6tJFy+bI1rYX833oNsTMIUT+hMcpCVIWTWbUytxHb8SGmN
84Bk9j+nyofYOyrSgNLCbZe01YFNbjH9u0f/DvGjRE8km32z073AwSEHoq7CTnJQ
fEqigBGTJ6FXVHUQM4BFVmdknmL9LMd7lg==
=BN2J
-----END PGP PUBLIC KEY BLOCK-----
EOF

      fi

  fi

  # Download the package with config files
  PKG_TYPE="sensor_w_cfg"

  check_host_version
  [ $? -ne 0 ] && log "Error: Unsupported platform $DISTRO-$VERSION" && rm -rf $TMP_DIR && return 1
  
  ARCH=$(uname -m)
  METHOD="GET"
  URI="/openapi/v1/sw_assets/download?pkg_type=$PKG_TYPE\&platform=$DISTRO-$VERSION\&arch=$ARCH\&sensor_version=$SENSOR_VERSION"
  URI_NO_ESC="/openapi/v1/sw_assets/download?pkg_type=$PKG_TYPE&platform=$DISTRO-$VERSION&arch=$ARCH&sensor_version=$SENSOR_VERSION"
  CHK_SUM=""
  CONTENT_TYPE=""
  TS=$(date -u "+%Y-%m-%dT%H:%M:%S+0000")
  HOST="https://64.100.1.213"
  API_KEY=3b00ca87248045c1a4dd80b443e16cc4
  API_SECRET=e045cf75a258653e60fc014a83a6a2feb8f63191
  ZIP_FILE=tet-sensor-$DISTRO-$VERSION.zip
  RPM_FILE=tet-sensor-$DISTRO-$VERSION.rpm

  rm -rf $ZIP_FILE
  # Calculate the signature based on the params
  # <httpMethod>\n<requestURI>\n<chksumOfBody>\n<ContentType>\n<TimestampHeader>
  count=0
  until [ $count -ge 3 ]
  do
    MSG=$(echo -n -e "$METHOD\n$URI_NO_ESC\n$CHK_SUM\n$CONTENT_TYPE\n$TS\n")
    SIG=$(echo "$MSG"| openssl dgst -sha256 -hmac $API_SECRET -binary | openssl enc -base64)
    REQ=$(echo -n "curl -v --cacert ta_sensor_ca.pem $HOST$URI -w '%{http_code}' -H 'Timestamp: $TS' -H 'Id: $API_KEY' -H 'Authorization: $SIG' -o $ZIP_FILE")
    status_code=$(sh -c "$REQ")
    echo "status code: $status_code"
    if [ -e $ZIP_FILE ] && [ "$status_code" == "200" ] ; then
      break
    fi
    log "Error: Sensor pkg download fails"
    count=$[$count+1]
    echo "Retry in 15 seconds..."
    sleep 15
  done

  unzip $ZIP_FILE
  [ $? -ne 0 ] && log "Sensor pkg can not be extracted" && cd $EXEC_DIR && return 1 

  # copy the rpm file
  inner_rpm=$(ls tet-sensor*.rpm| head -1 | awk '{print $1}')
  cp $inner_rpm $RPM_FILE

  # Execute the rest from outside of temporary folder
  cd $EXEC_DIR

  # Verify that the rpm package is signed by Tetration
  log "Verifying Linux RPM package ..."
  LOCAL_RPMDB=$TMP_DIR
  rpm --initdb --dbpath $LOCAL_RPMDB
  rpm --dbpath $LOCAL_RPMDB --import $TMP_DIR/sensor-gpg.key
  gpg_ok=$(rpm -K $TMP_DIR/$RPM_FILE --dbpath $LOCAL_RPMDB)
  ret=$?
  if [ $ret -eq 0 ] ; then
    pgp_signed=$(echo $gpg_ok | grep "gpg\|pgp")
    if [ "$pgp_signed" = "" ] ; then
      log "Error: RPM signature verification failed"
      rm -rf $TMP_DIR
      return 1
    else
      log "RPM package is PGP-signed"
    fi
  else
    log "Error: Cannot verify RPM package - $pgp_ok"
    rm -rf $TMP_DIR
    return 1
  fi

  log "Installing Linux Sensor ..."
  # make sure we are starting from clean state
  mkdir -p /usr/local/tet/chroot /usr/local/tet/conf /usr/local/tet/cert/
  rm -f /usr/local/tet/site.cfg
  [ -e $TMP_DIR/sensor.cfg ] && install -m 644 $TMP_DIR/sensor.cfg /usr/local/tet/conf/.sensor_config
  [ -e $TMP_DIR/enforcer.cfg ] && install -m 644 $TMP_DIR/enforcer.cfg /usr/local/tet/conf/enforcer.cfg
  install -m 644 $TMP_DIR/ta_sensor_ca.pem /usr/local/tet/cert/ca.cert
  # sensor rpm is supposed to check this file and start enforcer service
  sh -c "echo -n "$SENSOR_TYPE" > /usr/local/tet/sensor_type"
  # copy user.cfg file if the old file does not exist
  test -f /usr/local/tet/user.cfg
  [ $? -ne 0 ] && [ -e $TMP_DIR/tet.user.cfg ] && install -m 644 $TMP_DIR/tet.user.cfg /usr/local/tet/user.cfg

  RPM_INSTALL_OPTION=
  [ "$DISTRO" = "Ubuntu" ] && RPM_INSTALL_OPTION="--nodeps"
  ret=0
  rpm -Uvh $RPM_INSTALL_OPTION $TMP_DIR/$RPM_FILE
  if [ $? -ne 0 ] ; then
    log "Error: the command rpm -Uvh has failed, please check errors"
    ret=1
  else
    log "### Installation succeeded"
  fi

  # Clean up temporary files and folders
  log "Cleaning temporary files"
  rm -rf $TMP_DIR

  return $ret
}

for i in "$@"; do
case $i in
  --skip-pre-check)
  DO_PRECHECK=0
  shift
  ;;
  --no-install)
  NO_INSTALL=1
  shift
  ;;
  --logfile=*)
  LOG_FILE="${i#*=}"
  truncate -s 0 $LOG_FILE
  shift
  ;;
  --skip-ipv6-check)
  SKIP_IPV6=1
  shift
  ;;
  --sensor-version=*)
  SENSOR_VERSION="${i#*=}"
  shift
  ;;
  --help)
  print_version
  echo
  print_usage
  exit 0
  shift
  ;;
  --version)
  print_version
  exit 0
  shift
  ;;
  --ls)
  LIST_VERSION="True"
  shift
  ;;
  *)
  echo "Invalid option: $@"
  print_usage
  exit 240
  ;;
esac
done

# Script needs to to be invoked as root
if [ "$UID" != 0 ] ; then
  log "Script needs to be invoked as root"
  exit 255
fi

# --ls to list all available sensor versions. will not download or install anything
if [ $LIST_VERSION == "True" ] ; then
  list_available_versions
  if [ $? -ne 0 ] ; then
    log "Failed to list all available sensor versions"
    exit 1
  fi
  exit 0
fi

# Make sure pre-check has passed
if [ $DO_PRECHECK -eq 1 ] ; then
  pre_check
  PRECHECK_RET=$?
  if [ $PRECHECK_RET -ne 0 ] ; then
    log "Pre-check has failed with code $PRECHECK_RET, please fix the errors"
    exit $PRECHECK_RET
  fi
fi

# Only proceed with installation if instructed
if [ $NO_INSTALL -eq 0 ] ; then
  perform_install
  if [ $? -ne 0 ] ; then
    log "Installation has failed, please check and fix the errors"
    exit 239
  fi
fi

log ""
log "### All tasks are done ###"
exit 0
