// Imports the curated catalogue (backend/data/*.json, exported from lib/data/mock_data.dart) into Firestore.
//
//   npm run seed            → the real project (needs backend/.env with a service account)
//   npm run seed:emulator   → the local emulator (firebase emulators:start --only firestore)
//
// Documents are merged, so re-running updates existing jobs and skills without touching user data.
// Jobs missing from jobs.json are marked inactive rather than deleted, keeping old applications readable.
import { readFile } from 'node:fs/promises';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

try {
  process.loadEnvFile(new URL('../.env', import.meta.url));
} catch {
  // No .env: fine for the emulator, whose script sets the variables itself.
}

type Doc = { id: string } & Record<string, unknown>;

const emulator = process.env.FIRESTORE_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT;
if (!projectId) throw new Error('GCLOUD_PROJECT belum diisi (lihat backend/.env.example).');

initializeApp(emulator ? { projectId } : { projectId, credential: applicationDefault() });
const db = getFirestore();

async function load(name: string): Promise<Doc[]> {
  const docs = JSON.parse(await readFile(new URL(`../data/${name}`, import.meta.url), 'utf8')) as Doc[];
  for (const d of docs) if (!d.id) throw new Error(`${name}: ada dokumen tanpa id`);
  return docs;
}

async function seed(collection: string, docs: Doc[], extra: Record<string, unknown>) {
  const batch = db.batch();
  for (const { id, ...data } of docs) {
    batch.set(db.collection(collection).doc(id), { ...data, ...extra }, { merge: true });
  }
  await batch.commit();
}

const jobs = await load('jobs.json');
const skills = await load('skills.json');
const now = FieldValue.serverTimestamp();

await seed('jobs', jobs, { active: true, curatedAt: now });
await seed('skills', skills, { updatedAt: now });

const keep = new Set(jobs.map((j) => j.id));
const stale = (await db.collection('jobs').where('active', '==', true).get()).docs.filter((d) => !keep.has(d.id));
await Promise.all(stale.map((d) => d.ref.update({ active: false })));

console.log(
  `${emulator ? `Emulator ${emulator}` : `Proyek ${projectId}`}: ${jobs.length} lowongan, ${skills.length} skill` +
    (stale.length ? `, ${stale.length} lowongan lama dinonaktifkan` : ''),
);
