import admin from 'firebase-admin';

let firebaseApp;

function getFirebaseApp() {
  if (firebaseApp) return firebaseApp;

  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    return null;
  }

  if (!admin.apps.length) {
    // When Auth Emulator is active, verifyIdToken is local — no real credential needed.
    const credential = process.env.FIREBASE_AUTH_EMULATOR_HOST
      ? undefined
      : admin.credential.applicationDefault();
    firebaseApp = admin.initializeApp({ ...(credential && { credential }), projectId });
  } else {
    firebaseApp = admin.app();
  }

  return firebaseApp;
}

export async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Missing Bearer token.' });
  }

  try {
    const app = getFirebaseApp();

    if (!app) {
      return res.status(500).json({
        error: 'Firebase not configured. Set FIREBASE_PROJECT_ID and credentials.'
      });
    }

    const decoded = await admin.auth().verifyIdToken(token);
    req.auth = {
      uid: decoded.uid,
      email: decoded.email || null,
      name: decoded.name || null
    };

    return next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired token.' });
  }
}

export async function deleteFirebaseUser(uid) {
  const app = getFirebaseApp();
  if (app) {
    await admin.auth().deleteUser(uid);
  }
}

