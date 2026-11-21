// Amplify configuration — tells the AWS Amplify library how to talk
// to our Cognito User Pool. Values come from environment variables that
// Terraform emits via `terraform output frontend_env_block`.
// Imported once at app boot (see main.tsx) so Amplify is ready before
// any component calls fetchAuthSession() or signInWithRedirect().

import { Amplify } from "aws-amplify";

const region = import.meta.env.VITE_AWS_REGION;
const userPoolId = import.meta.env.VITE_COGNITO_USER_POOL_ID;
const userPoolClientId = import.meta.env.VITE_COGNITO_APP_CLIENT_ID;
const domain = import.meta.env.VITE_COGNITO_DOMAIN;
const redirect = import.meta.env.VITE_REDIRECT_URL;

if (!region || !userPoolId || !userPoolClientId || !domain || !redirect) {
  // Surfaced at boot so misconfig is obvious during the demo.
  console.error("Missing Amplify/Cognito env vars. Fill frontend/.env.local from `terraform output`.");
}

Amplify.configure({
  Auth: {
    Cognito: {
      userPoolId,
      userPoolClientId,
      loginWith: {
        oauth: {
          domain,
          scopes: ["openid", "email", "profile"],
          redirectSignIn: [redirect],
          redirectSignOut: [redirect],
          responseType: "code",
        },
      },
    },
  },
});
