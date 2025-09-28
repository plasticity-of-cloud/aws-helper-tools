#!/bin/bash
echo "Cleaning up resources..."
aws ec2 terminate-instances --region eu-west-1 --instance-ids i-09b20117f9263c869
aws ec2 release-address --region eu-west-1 --allocation-id eipalloc-0fe21275bedbbda6c
aws ec2 delete-launch-template --region eu-west-1 --launch-template-name hibernation-spot-template-1759021499
aws ec2 delete-security-group --region eu-west-1 --group-id sg-0f62b4fd6a012de61
aws s3 rm s3://dcv-workstation-scripts-1759021496-423b2830 --recursive
aws s3 rb s3://dcv-workstation-scripts-1759021496-423b2830
echo "Cleanup complete"
