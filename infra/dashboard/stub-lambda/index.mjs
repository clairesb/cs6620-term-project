// Stub Lambda behind API Gateway. Replace with Member 2's real orchestrator
// once their backend is ready. For Milestone 1, this proves the full
// browser -> Cognito -> API Gateway -> Lambda path with a Cognito JWT.

const now = new Date();
const iso = (offsetMs) => new Date(now.getTime() - offsetMs).toISOString();

const SCANS = [
  {
    id: "scan-20261117-001",
    engine: "sast",
    target: "online-banking-api",
    startedAt: iso(3 * 60 * 60 * 1000),
    status: "completed",
    counts: { high: 2, medium: 3, low: 5 },
    findings: [
      { id: "f1", severity: "HIGH", title: "Hardcoded API key" },
      { id: "f2", severity: "HIGH", title: "SQL injection in /accounts" },
      { id: "f3", severity: "MEDIUM", title: "Weak randomness (Math.random)" },
    ],
  },
  {
    id: "scan-20261117-002",
    engine: "pentest",
    target: "online-banking-api",
    startedAt: iso(60 * 60 * 1000),
    status: "completed",
    counts: { high: 1, medium: 2, low: 1 },
    findings: [
      { id: "p1", severity: "HIGH", title: "Missing auth on /transactions" },
      { id: "p2", severity: "MEDIUM", title: "Verbose error responses" },
    ],
  },
];

const FINDING_DETAILS = {
  "scan-20261117-001/f1": {
    id: "f1", scanId: "scan-20261117-001", severity: "HIGH",
    title: "Hardcoded API key",
    description: "Hardcoded secret detected in src/config.js:42. Secrets must be loaded from AWS Secrets Manager.",
    file: "src/config.js", line: 42,
    recommendation: "Move the secret to Secrets Manager and load via GetSecretValue at runtime.",
  },
  "scan-20261117-001/f2": {
    id: "f2", scanId: "scan-20261117-001", severity: "HIGH",
    title: "SQL injection in /accounts",
    description: "String concatenation into SQL query at routes/accounts.js:88.",
    file: "routes/accounts.js", line: 88,
    recommendation: "Use parameterized queries (pg library's $1/$2 placeholders).",
  },
  "scan-20261117-002/p1": {
    id: "p1", scanId: "scan-20261117-002", severity: "HIGH",
    title: "Missing auth on /transactions",
    description: "Pentest observed /transactions returning 200 without an Authorization header.",
    recommendation: "Require Cognito JWT via API Gateway authorizer on the /transactions route.",
  },
};

function response(status, body) {
  return {
    statusCode: status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Authorization, Content-Type",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    },
    body: JSON.stringify(body),
  };
}

export const handler = async (event) => {
  const method = event.requestContext?.http?.method ?? event.httpMethod;
  const path = event.rawPath ?? event.path ?? "";

  console.log(JSON.stringify({ method, path, claims: event.requestContext?.authorizer?.jwt?.claims }));

  if (method === "OPTIONS") return response(204, {});
  if (method === "GET" && path === "/health") return response(200, { ok: true });
  if (method === "GET" && path === "/scans") return response(200, { scans: SCANS });

  const findingMatch = path.match(/^\/scans\/([^/]+)\/findings\/([^/]+)$/);
  if (method === "GET" && findingMatch) {
    const [, scanId, findingId] = findingMatch;
    const detail = FINDING_DETAILS[`${scanId}/${findingId}`];
    if (!detail) return response(404, { error: "finding not found" });
    return response(200, detail);
  }

  const exportMatch = path.match(/^\/scans\/([^/]+)\/export$/);
  if (method === "POST" && exportMatch) {
    const [, scanId] = exportMatch;
    return response(200, {
      scanId,
      bundleUrl: `https://example-evidence-bucket.s3.amazonaws.com/${scanId}/evidence.json`,
      generatedAt: new Date().toISOString(),
      note: "Stub URL; Member 2's orchestrator will return a real presigned S3 URL.",
    });
  }

  return response(404, { error: "no route", method, path });
};
