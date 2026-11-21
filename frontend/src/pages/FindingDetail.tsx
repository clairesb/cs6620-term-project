// Finding detail page — drills into a single vulnerability inside
// a scan. Shows severity, location (file:line for SAST, URL for
// Pentest), full description, and remediation recommendation.
// Backed by GET /scans/{scanId}/findings/{findingId}.

import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { getFinding } from "../lib/api";

type FindingDetail = {
  id: string;
  severity: string;
  title: string;
  description: string;
  file?: string;
  line?: number;
  recommendation?: string;
  scanId: string;
};

export default function FindingDetailPage() {
  const { scanId = "", findingId = "" } = useParams();
  const [finding, setFinding] = useState<FindingDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getFinding(scanId, findingId)
      .then(setFinding)
      .catch((e) => setError(String(e)));
  }, [scanId, findingId]);

  if (error) return <p style={{ color: "crimson" }}>Error: {error}</p>;
  if (!finding) return <p>Loading finding…</p>;

  return (
    <div>
      <p><Link to="/">← back to scans</Link></p>
      <h2>[{finding.severity}] {finding.title}</h2>
      <p><strong>Scan:</strong> <code>{finding.scanId}</code></p>
      <p><strong>Finding:</strong> <code>{finding.id}</code></p>
      {finding.file && <p><strong>Location:</strong> {finding.file}{finding.line ? `:${finding.line}` : ""}</p>}
      <h3>Description</h3>
      <p>{finding.description}</p>
      {finding.recommendation && (
        <>
          <h3>Recommendation</h3>
          <p>{finding.recommendation}</p>
        </>
      )}
    </div>
  );
}
