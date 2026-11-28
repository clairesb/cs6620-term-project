# CS6620 Cloud Computing - Spring 2026
# Semester Project: Cloud Security Platform

Docker containers are stored https://hub.docker.com/repository/docker/clairesb/pentest/general and https://hub.docker.com/repository/docker/clairesb/sast/general. Image versions are tagged with github commit ids; I can look into also implementing a latest tag if y'all would like. 

The containers need two environment variables to run properly on fargate:
`AUDIT_BUCKET`: the bucket where the logs will be written
`AWS_REGION`: was always us-east-1 for me

Run `terraform apply -var "image_tag=[tag_goes_here]"` to deploy my test infrastructure: an ALB so that each of the services have static IPs, which forwards traffic to the services themselves (deployed on fargate clusters, one task each). DO NOT USE THIS INFRASTRUCTURE IN PROD!

Here's a command I used to test my pentest container locally with localstack: `docker run -d   --name pentest-audit --rm -p 3000:3000 --add-host=host.docker.internal:host-gateway  -e AUDIT_BUCKET=test-bucket -e AWS_ENDPOINT_URL=http://host.docker.internal:4566  -e AWS_REGION=us-east-1 -e AWS_ACCESS_KEY_ID=test  -e AWS_SECRET_ACCESS_KEY=test pentest`
