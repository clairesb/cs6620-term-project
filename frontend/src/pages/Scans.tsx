// Scans list page — the compliance officer's landing view.
// Fetches GET /scans once on mount, renders one row per scan
// (both SAST and Pentest engines appear here), and offers a
// per-row "Export" button that triggers POST /scans/{id}/export
// to generate an auditor-ready evidence bundle.

import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { exportEvidence, getScans } from "../lib/api";

type Finding = { id: string; severity: string; title: string };
type Scan = {
  id: string;
  target: string;
  engine: "sast" | "pentest";
  startedAt: string;
  status: string;
  counts: { high: number; medium: number; low: number };
  findings: Finding[];
};

export default function Scans() {
  const [scans, setScans] = useState<Scan[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [exporting, setExporting] = useState<string | null>(null);

  useEffect(() => {
    getScans()
      .then((data) => setScans(data.scans ?? data))
      .catch((e) => setError(String(e)));
  }, []);

  if (error) return <p style={{ color: "crimson" }}>Error: {error}</p>;
  if (!scans) return <p>Loading scans…</p>;

  return (
    <div>
      <h2>Scans</h2>
      <table style={{ width: "100%", borderCollapse: "collapse" }}>
        <thead>
          <tr style={{ textAlign: "left", borderBottom: "1px solid #ddd" }}>
            <th>ID</th><th>Engine</th><th>Target</th><th>Started</th>
            <th>H / M / L</th><th>Findings</th><th>Export</th>
          </tr>
        </thead>
        <tbody>
          {scans.map((s) => (
            <tr key={s.id} style={{ borderBottom: "1px solid #eee" }}>
              <td style={{ fontFamily: "monospace" }}>{s.id}</td>
              <td>{s.engine}</td>
              <td>{s.target}</td>
              <td>{new Date(s.startedAt).toLocaleString()}</td>
              <td>{s.counts.high} / {s.counts.medium} / {s.counts.low}</td>
              <td>
                {s.findings.slice(0, 3).map((f) => (
                  <div key={f.id}>
                    <Link to={`/scans/${s.id}/findings/${f.id}`}>
                      [{f.severity}] {f.title}
                    </Link>
                  </div>
                ))}
              </td>
              <td>
                <button
                  disabled={exporting === s.id}
                  onClick={async () => {
                    setExporting(s.id);
                    try {
                      const res = await exportEvidence(s.id);
                      alert(`Evidence bundle: ${res.bundleUrl ?? JSON.stringify(res)}`);
                    } catch (e) {
                      alert(String(e));
                    } finally {
                      setExporting(null);
                    }
                  }}
                >
                  {exporting === s.id ? "Exporting…" : "Export"}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
