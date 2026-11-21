// Authenticated API client — every function here grabs the current
// Cognito ID token from Amplify and attaches it as a Bearer header
// before calling API Gateway. If the stored token has expired,
// fetchAuthSession() silently refreshes it first. Components never
// handle tokens directly.

import { fetchAuthSession } from "aws-amplify/auth";

const base = import.meta.env.VITE_API_BASE_URL;

async function authHeader(): Promise<HeadersInit> {
  const session = await fetchAuthSession();
  const token = session.tokens?.idToken?.toString();
  if (!token) throw new Error("No ID token — are you signed in?");
  return { Authorization: `Bearer ${token}` };
}

export async function getScans() {
  const res = await fetch(`${base}/scans`, { headers: await authHeader() });
  if (!res.ok) throw new Error(`GET /scans failed: ${res.status}`);
  return res.json();
}

export async function getFinding(scanId: string, findingId: string) {
  const res = await fetch(`${base}/scans/${scanId}/findings/${findingId}`, {
    headers: await authHeader(),
  });
  if (!res.ok) throw new Error(`GET finding failed: ${res.status}`);
  return res.json();
}

export async function exportEvidence(scanId: string) {
  const res = await fetch(`${base}/scans/${scanId}/export`, {
    method: "POST",
    headers: await authHeader(),
  });
  if (!res.ok) throw new Error(`POST export failed: ${res.status}`);
  return res.json();
}
