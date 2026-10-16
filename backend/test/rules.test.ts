// Firestore security rules (firestore.rules), run against the emulator:
//   firebase emulators:exec --project demo-karirin --only firestore "npm --prefix backend test"
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { Bytes, deleteDoc, doc, getDoc, setDoc, updateDoc, writeBatch } from 'firebase/firestore';
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

describe('foto profil', () => {
  const image = (size: number) => Bytes.fromUint8Array(new Uint8Array(size));
  test('pemilik dapat menyimpan, membaca, dan menghapus fotonya', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'profilePhotos/alice'), { image: image(40 * 1024) }));
    await assertSucceeds(getDoc(doc(alice(), 'profilePhotos/alice')));
    await assertSucceeds(deleteDoc(doc(alice(), 'profilePhotos/alice')));
  });
  test('foto pengguna lain tidak dapat dibaca atau ditulis', async () => {
    await assertFails(getDoc(doc(alice(), 'profilePhotos/bob')));
    await assertFails(setDoc(doc(alice(), 'profilePhotos/bob'), { image: image(1024) }));
    await assertFails(getDoc(doc(guest(), 'profilePhotos/alice')));
  });
  test('foto harus berupa bytes, maksimal 600 KB, tanpa field lain', async () => {
    await assertFails(setDoc(doc(alice(), 'profilePhotos/alice'), { image: image(601 * 1024) }));
    await assertFails(setDoc(doc(alice(), 'profilePhotos/alice'), { image: 'data:image/png;base64,AAAA' }));
    await assertFails(setDoc(doc(alice(), 'profilePhotos/alice'), { image: image(1024), name: 'x' }));
  });
});

describe('lamar cepat', () => {
  const part = (size: number) => ({ data: Bytes.fromUint8Array(new Uint8Array(size)) });
  const quick = (over: Record<string, unknown> = {}) => ({
    title: 'Admin Gudang',
    company: 'CV Berkah Logistik',
    status: 'dikirim',
    quick: true,
    letter: 'Dengan hormat, ...',
    cv: { size: 1200 * 1024, mimeType: 'application/pdf', parts: 2 },
    consent: { text: 'Saya setuju profil, CV, dan surat lamaran ini dikirim ke CV Berkah Logistik.' },
    ...over,
  });
  const send = async (db: ReturnType<typeof alice>, data = quick(), parts = [part(900 * 1024), part(300 * 1024)]) => {
    const batch = writeBatch(db);
    batch.set(doc(db, 'users/alice/applications/q1'), data);
    parts.forEach((p, i) => batch.set(doc(db, `users/alice/applications/q1/cv/${i}`), p));
    await batch.commit();
  };

  test('pemilik dapat mengirim lamaran dengan CV terpotong, lalu membaca dan menariknya', async () => {
    await assertSucceeds(send(alice()));
    await assertSucceeds(getDoc(doc(alice(), 'users/alice/applications/q1/cv/1')));
    await assertSucceeds(deleteDoc(doc(alice(), 'users/alice/applications/q1/cv/0')));
    await assertSucceeds(deleteDoc(doc(alice(), 'users/alice/applications/q1')));
  });
  test('status awal harus dikirim dan pengguna tidak dapat mengubahnya', async () => {
    await assertFails(send(alice(), quick({ status: 'diterima' })));
    await assertSucceeds(send(alice()));
    await assertFails(updateDoc(doc(alice(), 'users/alice/applications/q1'), { status: 'diterima' }));
    await assertFails(updateDoc(doc(alice(), 'users/alice/applications/q1'), { quick: false, status: 'diterima' }));
  });
  test('wajib ada persetujuan dan ukuran CV yang valid', async () => {
    await assertFails(send(alice(), quick({ consent: { text: '' } })));
    await assertFails(send(alice(), quick({ cv: { size: 6 * 1024 * 1024, parts: 7 } })));
  });
  test('potongan CV maksimal 900 KB, berupa bytes, dan hanya di bawah lamar cepat', async () => {
    await assertFails(send(alice(), quick(), [part(901 * 1024)]));
    await assertFails(send(alice(), quick(), [{ data: 'bukan-bytes' } as never]));
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/applications/a1'), { title: 'Kasir', company: 'Toko', status: 'dikirim' }));
    await assertFails(setDoc(doc(alice(), 'users/alice/applications/a1/cv/0'), part(1024)));
  });
  test('potongan CV tidak dapat diganti setelah terkirim', async () => {
    await assertSucceeds(send(alice()));
    await assertFails(setDoc(doc(alice(), 'users/alice/applications/q1/cv/0'), part(10)));
  });
  test('lamaran dan CV pengguna lain tidak dapat dibaca', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users/bob/applications/q9'), quick());
      await setDoc(doc(ctx.firestore(), 'users/bob/applications/q9/cv/0'), part(10));
    });
    await assertFails(getDoc(doc(alice(), 'users/bob/applications/q9')));
    await assertFails(getDoc(doc(alice(), 'users/bob/applications/q9/cv/0')));
  });
});

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
  test('lamaran situs perusahaan tidak dapat diubah menjadi lamar cepat', async () => {
    const ref = doc(alice(), 'users/alice/applications/a1');
    await assertSucceeds(setDoc(ref, { title: 'Kasir', company: 'Toko', status: 'dikirim' }));
    await assertSucceeds(updateDoc(ref, { status: 'tes' }));
    await assertFails(updateDoc(ref, { quick: true }));
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
