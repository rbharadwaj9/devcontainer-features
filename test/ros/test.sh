#!/bin/bash
set -e
. dev-container-features-test-lib

# The ROS feature exits 0 without writing anything when /opt/ros is absent.
# On a plain Ubuntu base image the checks below would both fail, so we skip
# them when no ROS distro is installed.
if [ ! -d /opt/ros ] || [ -z "$(ls -A /opt/ros 2>/dev/null)" ]; then
    echo "No /opt/ros found — skipping ROS-specific checks (expected on non-ROS base images)."
    reportResults
    exit 0
fi

check "bashrc_ros created"       test -f "$HOME/.bashrc_ros"
check "bashrc_ros sourced"       sh -c 'grep -q "bashrc_ros" "$HOME/.bashrc"'
check "distro setup referenced"  sh -c 'grep -q "/opt/ros/" "$HOME/.bashrc_ros"'

reportResults
