// App shell — handles the top-level sign in / sign out state and
// routing between the scans list and finding detail pages.
// If the user is not signed in, we show a sign-in prompt instead of
// the routed pages, so no component ever tries to call the API
// without a valid Cognito session.

import { useEffect, useState } from "react";
import { Routes, Route, Link, Navigate } from "react-router-dom";
import {
  signInWithRedirect,
  signOut,
  fetchAuthSession,
  type AuthSession,
} from "aws-amplify/auth";
import Scans from "./pages/Scans";
import FindingDetail from "./pages/FindingDetail";

export default function App() {
  const [session, setSession] = useState<AuthSession | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchAuthSession()
      .then((s) => setSession(s))
      .catch(() => setSession(null))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <p style={{ padding: 24 }}>Loading…</p>;

  const signedIn = Boolean(session?.tokens?.idToken);

  return (
    <div style={{ fontFamily: "system-ui, sans-serif", padding: 24, maxWidth: 960, margin: "0 auto" }}>
      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 }}>
        <h1 style={{ margin: 0, fontSize: 20 }}>
          <Link to="/" style={{ textDecoration: "none", color: "inherit" }}>
            Compliance & Audit Dashboard
          </Link>
        </h1>
        {signedIn ? (
          <button onClick={() => signOut()}>Sign out</button>
        ) : (
          <button onClick={() => signInWithRedirect()}>Sign in with Cognito</button>
        )}
      </header>

      {!signedIn ? (
        <div>
          <p>Sign in with your Cognito account to view scans and export evidence.</p>
        </div>
      ) : (
        <Routes>
          <Route path="/" element={<Scans />} />
          <Route path="/scans/:scanId/findings/:findingId" element={<FindingDetail />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      )}
    </div>
  );
}
