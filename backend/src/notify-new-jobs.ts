// "Lowongan baru yang cocok": after new jobs are seeded, tell every user whose profile scores at least 75 on them
// (Sangat Cocok) and who kept the setting on. Each user gets a notification document (shown in the app's
// notification sheet) and a push message on every registered device.
//
//   npm run notify -- j21 j22            → notify for these job ids
//   npm run notify -- j21 --dry-run      → only print who would be notified
//
// Re-running is safe: a user is notified about a job at most once (document id job-<jobId>).
// Credentials as for seed.ts (backend/.env); FIRESTORE_EMULATOR_HOST reads users from the emulator while push
// messages still go through the real FCM.
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { formatScore, matchScore, type Job, type Profile } from './match-score.js';

try {
  process.loadEnvFile(new URL('../.env', import.meta.url));
} catch {
  // Variables may come from the shell or CI instead.
}

const THRESHOLD = 75;
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const jobIds = args.filter((a) => !a.startsWith('--'));
if (jobIds.length === 0) {
  console.log('Pakai: npm run notify -- <jobId> [jobId ...] [--dry-run]');
  process.exit(1);
}

const projectId = process.env.GCLOUD_PROJECT;
if (!projectId) throw new Error('GCLOUD_PROJECT belum diisi (lihat backend/.env.example).');
initializeApp({ projectId, credential: applicationDefault() });
const db = getFirestore();
const messaging = getMessaging();

type JobDoc = Job & { title: string; company: string; active?: boolean };

const jobs: (JobDoc & { id: string })[] = [];
for (const id of jobIds) {
  const snap = await db.collection('jobs').doc(id).get();
  const data = snap.data() as JobDoc | undefined;
  if (!data || data.active === false) {
    console.log(`${id}: tidak ada atau tidak aktif, dilewati (jalankan npm run seed dulu)`);
    continue;
  }
  jobs.push({ id, ...data });
}

/** Push failures that mean the token will never work again and should be forgotten. */
const deadToken = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token', 'messaging/invalid-argument']);

let notified = 0;
let pushed = 0;
const profiles = await db.collection('profiles').get();
for (const profileDoc of profiles.docs) {
  const uid = profileDoc.id;
  const profile = profileDoc.data() as Profile;
  const userRef = db.collection('users').doc(uid);
  const user = (await userRef.get()).data() ?? {};
  if (user.settings?.notifyNewJobs === false) continue;
  const tokens: string[] = Array.isArray(user.fcmTokens) ? user.fcmTokens : [];

  for (const job of jobs) {
    const score = matchScore(job, profile);
    if (score < THRESHOLD) continue;
    const ref = userRef.collection('notifications').doc(`job-${job.id}`);
    if ((await ref.get()).exists) continue;

    const title = 'Lowongan baru yang cocok';
    const body = `${job.title} di ${job.company} cocok ${formatScore(score)} dengan profilmu.`;
    console.log(`${dryRun ? '[uji] ' : ''}${uid} ← ${job.id} (${formatScore(score)}), ${tokens.length} perangkat`);
    if (dryRun) continue;

    await ref.set({ type: 'new_job', title, body, jobId: job.id, score, read: false, createdAt: FieldValue.serverTimestamp() });
    notified++;
    if (tokens.length === 0) continue;

    const res = await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { jobId: job.id },
      android: { priority: 'high', notification: { channelId: 'new_jobs' } },
    });
    pushed += res.successCount;
    const dead = res.responses.flatMap((r, i) => (!r.success && deadToken.has(r.error?.code ?? '') ? [tokens[i]] : []));
    if (dead.length) await userRef.update({ fcmTokens: FieldValue.arrayRemove(...dead) });
  }
}

console.log(dryRun ? 'Uji selesai, tidak ada yang dikirim.' : `${notified} notifikasi disimpan, ${pushed} push terkirim.`);
