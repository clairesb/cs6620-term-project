# Frontend hosting was removed because this Learner Lab's SCP denies:
#   - cloudfront:CreateOriginAccessControl   (identity-based policy)
#   - s3:GetBucketObjectLockConfiguration    (service control policy)
#
# The AWS Terraform provider v5 always calls GetBucketObjectLockConfiguration
# on bucket refresh, even when Object Lock is never enabled, so we cannot
# even create a plain S3 bucket under this SCP.
#
# Demo strategy: run the React app locally with `npm run dev` and point it at
# the real deployed Cognito + API Gateway + Lambda. The Cognito app client's
# callback_urls include http://localhost:5173/ so the OAuth round-trip works.
#
# For the team's final presentation, Member 1's infra account presumably has
# fewer SCP restrictions and can host the frontend there.
