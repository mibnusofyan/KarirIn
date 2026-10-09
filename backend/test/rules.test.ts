// Firestore security rules (firestore.rules), run against the emulator:
//   firebase emulators:exec --project demo-karirin --only firestore "npm --prefix backend test"
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, test } from 'vitest';

let env: RulesTestEnvironment;

const profile = {
  name: 'Rani Lestari',
  level: 's1',
  major: 'Manajemen',
  school: '-',
  city: 'Purwokerto',
  modes: ['kantor'],
  source: 'cvPdf',
  skills: ['Microsoft Excel'],
  exps: [],
  interests: [],
  learned: [],
};

beforeAll(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080').split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-karirin',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'), host, port: Number(port) },
  });
});

afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'jobs/j1'), { title: 'Staf Administrasi Keuangan', active: true });
    await setDoc(doc(db, 'skills/sql'), { name: 'SQL' });
    await setDoc(doc(db, 'users/bob'), { email: 'bob@contoh.id' });
    await setDoc(doc(db, 'profiles/bob'), profile);
    await setDoc(doc(db, 'users/alice/notifications/n1'), { title: 'Lowongan baru', read: false });
  });
});

const alice = () => env.authenticatedContext('alice').firestore();
const guest = () => env.unauthenticatedContext().firestore();

describe('katalog', () => {
  test('pengguna login dapat membaca lowongan dan skill', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'jobs/j1')));
    await assertSucceeds(getDoc(doc(alice(), 'skills/sql')));
  });
  test('tamu tidak dapat membaca katalog', async () => {
    await assertFails(getDoc(doc(guest(), 'jobs/j1')));
  });
  test('aplikasi tidak dapat menulis katalog', async () => {
    await assertFails(setDoc(doc(alice(), 'jobs/j99'), { title: 'Palsu' }));
    await assertFails(updateDoc(doc(alice(), 'jobs/j1'), { title: 'Diubah' }));
    await assertFails(setDoc(doc(alice(), 'skills/x'), { name: 'X' }));
  });
});

describe('data milik pengguna', () => {
  test('pemilik dapat membuat, membaca, dan menghapus dokumen users dan profiles-nya', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'users/alice'), { email: 'alice@contoh.id' }));
    await assertSucceeds(setDoc(doc(alice(), 'profiles/alice'), profile));
    await assertSucceeds(getDoc(doc(alice(), 'profiles/alice')));
    await assertSucceeds(deleteDoc(doc(alice(), 'profiles/alice')));
    await assertSucceeds(deleteDoc(doc(alice(), 'users/alice')));
  });
  test('tidak dapat membaca atau menulis data pengguna lain', async () => {
    await assertFails(getDoc(doc(alice(), 'users/bob')));
    await assertFails(getDoc(doc(alice(), 'profiles/bob')));
    await assertFails(setDoc(doc(alice(), 'profiles/bob'), profile));
    await assertFails(deleteDoc(doc(alice(), 'users/bob')));
  });
  test('profil harus punya jenjang valid dan maksimal 60 skill', async () => {
    await assertFails(setDoc(doc(alice(), 'profiles/alice'), { ...profile, level: 's3' }));
    await assertFails(setDoc(doc(alice(), 'profiles/alice'), { ...profile, skills: 'Excel' }));
    const many = Array.from({ length: 61 }, (_, i) => `Skill ${i}`);
    await assertFails(setDoc(doc(alice(), 'profiles/alice'), { ...profile, skills: many }));
  });
  test('lamaran: status harus salah satu tahap', async () => {
    const app = { title: 'Kasir', company: 'Toko Swalayan Mitra' };
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/applications/a1'), { ...app, status: 'dikirim' }));
    await assertFails(setDoc(doc(alice(), 'users/alice/applications/a2'), { ...app, status: 'menang' }));
    await assertFails(setDoc(doc(alice(), 'users/bob/applications/a1'), { ...app, status: 'dikirim' }));
  });
  test('sesi wawancara tidak dapat diubah setelah disimpan', async () => {
    const ref = doc(alice(), 'users/alice/interviews/s1');
    await assertSucceeds(setDoc(ref, { jobId: 'j1' }));
    await assertFails(updateDoc(ref, { jobId: 'j2' }));
  });
  test('notifikasi: hanya dapat ditandai dibaca, tidak dapat dibuat aplikasi', async () => {
    const ref = doc(alice(), 'users/alice/notifications/n1');
    await assertSucceeds(updateDoc(ref, { read: true }));
    await assertFails(updateDoc(ref, { title: 'Diubah' }));
    await assertFails(setDoc(doc(alice(), 'users/alice/notifications/n2'), { title: 'Buatan sendiri' }));
  });
});
