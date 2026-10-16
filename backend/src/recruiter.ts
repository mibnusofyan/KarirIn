// The recruiter side of Lamar cepat for the KarirIn partner (demo) companies. The recruiter dashboard is out of scope
// for the mobile competition, so the team plays the recruiter from here.
//
//   npm run recruiter -- inbox                                   → list applications, save CV + summary to inbox/
//   npm run recruiter -- status <id> wawancara --note "Senin 27 Okt, 10.00 via Zoom"
//   npm run recruiter -- status <id> ditolak --dry-run           → only print what would change
//
// A status change updates the application (the app's Pelacak shows it right away), stores a notification and sends
// a push to every device of the applicant. inbox/ holds applicants' personal data: it is gitignored, delete it after
// the demo. Credentials as for seed.ts (backend/.env); FIRESTORE_EMULATOR_HOST works against the emulator.
import { mkdir, writeFile } from 'node:fs/promises';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, Timestamp, getFirestore, type QueryDocumentSnapshot } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

try {
  process.loadEnvFile(new URL('../.env', import.meta.url));
} catch {
  // Variables may come from the shell instead.
}

const STAGES = { dikirim: 'Dikirim', tes: 'Tes', wawancara: 'Wawancara', diterima: 'Diterima', ditolak: 'Ditolak' } as const;
type Stage = keyof typeof STAGES;
const LEVELS: Record<string, string> = { smaSmk: 'SMA/SMK', d3: 'D3', s1: 'S1' };

const [command, ...rest] = process.argv.slice(2);
const dryRun = rest.includes('--dry-run');
const noteAt = rest.indexOf('--note');
const note = noteAt >= 0 ? rest[noteAt + 1]?.trim() || undefined : undefined;
const positional = rest.filter((a, i) => !a.startsWith('--') && (noteAt < 0 || i !== noteAt + 1));

const projectId = process.env.GCLOUD_PROJECT;
if (!projectId) throw new Error('GCLOUD_PROJECT belum diisi (lihat backend/.env.example).');
const emulator = process.env.FIRESTORE_EMULATOR_HOST;
initializeApp(emulator ? { projectId } : { projectId, credential: applicationDefault() });
const db = getFirestore();

type Application = {
  title: string;
  company: string;
  status: Stage;
  appliedAt?: Timestamp;
  letter?: string;
  applicant?: {
    name?: string;
    level?: string;
    major?: string;
    school?: string;
    city?: string;
    skills?: string[];
    exps?: { title: string; org: string; months: number }[];
  };
  cv?: { size: number; parts: number };
  consent?: { text: string; acceptedAt?: Timestamp };
};

const date = (t?: Timestamp) => (t ? t.toDate().toLocaleString('id-ID', { dateStyle: 'medium', timeStyle: 'short' }) : '-');
const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40);
const uidOf = (d: QueryDocumentSnapshot) => d.ref.parent.parent!.id;

/** Every Lamar cepat application, newest first. A full collection-group scan: the demo has few applications, and a
 *  filtered collection-group query would need an extra index. */
async function quickApplications() {
  const snap = await db.collectionGroup('applications').get();
  return snap.docs
    .filter((d) => d.get('quick') === true)
    .sort((a, b) => (b.get('appliedAt')?.toMillis() ?? 0) - (a.get('appliedAt')?.toMillis() ?? 0));
}

async function inbox() {
  const apps = await quickApplications();
  if (apps.length === 0) {
    console.log('Belum ada lamaran Lamar cepat.');
    return;
  }
  const dir = new URL('../inbox/', import.meta.url);
  await mkdir(dir, { recursive: true });
  for (const d of apps) {
    const a = d.data() as Application;
    const p = a.applicant ?? {};
    const email = (await db.collection('users').doc(uidOf(d)).get()).get('email') ?? '-';
    const parts = (await d.ref.collection('cv').get()).docs.sort((x, y) => Number(x.id) - Number(y.id));
    const cv = Buffer.concat(parts.map((part) => Buffer.from(part.get('data'))));
    const complete = parts.length === a.cv?.parts && cv.length === a.cv?.size;
    const base = `${d.id}-${slug(p.name ?? 'pelamar')}-${slug(a.title)}`;
    if (cv.length > 0) await writeFile(new URL(`${base}.pdf`, dir), cv);
    const summary = [
      `Lamaran   : ${a.title} di ${a.company}`,
      `Pelamar   : ${p.name ?? '-'} <${email}>`,
      `Dikirim   : ${date(a.appliedAt)}`,
      `Status    : ${STAGES[a.status] ?? a.status}`,
      `ID        : ${d.id}`,
      `CV        : ${complete ? `${base}.pdf (${Math.ceil(cv.length / 1024)} KB)` : `TIDAK LENGKAP (${parts.length}/${a.cv?.parts ?? '?'} bagian)`}`,
      '',
      'Profil',
      `- Pendidikan  : ${LEVELS[p.level ?? ''] ?? p.level ?? '-'} ${p.major ?? ''}, ${p.school ?? '-'}`,
      `- Domisili    : ${p.city ?? '-'}`,
      `- Keterampilan: ${(p.skills ?? []).join(', ') || '-'}`,
      '- Pengalaman  :',
      ...(p.exps?.length ? p.exps.map((e) => `    ${e.title}, ${e.org} (${e.months} bulan)`) : ['    -']),
      '',
      'Surat lamaran',
      a.letter?.trim() || '(tidak diisi)',
      '',
      `Persetujuan: "${a.consent?.text ?? '-'}" (${date(a.consent?.acceptedAt)})`,
      '',
    ].join('\n');
    await writeFile(new URL(`${base}.txt`, dir), summary);
    console.log(`${d.id}  ${(STAGES[a.status] ?? a.status).padEnd(9)}  ${(p.name ?? '-').padEnd(22)}  ${a.title} · ${a.company}${complete ? '' : '  [CV tidak lengkap]'}`);
  }
  console.log(`\n${apps.length} lamaran. CV dan ringkasan tersimpan di backend/inbox/.`);
}

function message(stage: Stage, a: Application) {
  const base = {
    dikirim: `${a.company} menerima lamaranmu untuk ${a.title}.`,
    tes: `${a.company} mengundangmu mengikuti tes untuk ${a.title}.`,
    wawancara: `${a.company} mengundangmu wawancara untuk ${a.title}.`,
    diterima: `Selamat! ${a.company} menerimamu sebagai ${a.title}.`,
    ditolak: `${a.company} belum dapat melanjutkan lamaranmu untuk ${a.title}. Tetap semangat, cek peluang lain di KarirIn.`,
  }[stage];
  return note ? `${base} ${note}` : base;
}

/** Push failures that mean the token will never work again and should be forgotten. */
const deadToken = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token', 'messaging/invalid-argument']);

async function setStatus(id: string | undefined, stage: string | undefined) {
  if (!id || !stage) throw new Error('Pakai: npm run recruiter -- status <id> <tahap> [--note "..."] [--dry-run]');
  if (!(stage in STAGES)) throw new Error(`Tahap tidak dikenal: ${stage}. Pilih salah satu: ${Object.keys(STAGES).join(', ')}.`);
  const d = (await quickApplications()).find((x) => x.id === id);
  if (!d) throw new Error(`Lamaran ${id} tidak ditemukan. Lihat daftar dengan: npm run recruiter -- inbox`);
  const a = d.data() as Application;
  const s = stage as Stage;
  const title = `Status lamaran: ${STAGES[s]}`;
  const body = message(s, a);
  console.log(`${dryRun ? '[uji] ' : ''}${id}: ${a.status} → ${s} · ${a.applicant?.name ?? '-'} · ${a.title}\n  "${body}"`);
  if (dryRun) return;

  await d.ref.update({
    status: s,
    // A note belongs to one status (a test or interview schedule), so a change without one clears the old note.
    note: note ?? FieldValue.delete(),
    statusHistory: FieldValue.arrayUnion({ status: s, at: Timestamp.now(), by: 'perusahaan' }),
    updatedAt: FieldValue.serverTimestamp(),
  });
  const userRef = db.collection('users').doc(uidOf(d));
  await userRef
    .collection('notifications')
    .doc(`app-${id}-${s}`)
    .set({ type: 'application_status', title, body, applicationId: id, read: false, createdAt: FieldValue.serverTimestamp() });

  const tokens: string[] = (await userRef.get()).get('fcmTokens') ?? [];
  if (tokens.length === 0) {
    console.log('Status diperbarui. Pelamar belum punya perangkat terdaftar untuk push; notifikasi tersimpan di aplikasi.');
    return;
  }
  try {
    const res = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { applicationId: id },
      android: { priority: 'high', notification: { channelId: 'application_status' } },
    });
    const dead = res.responses.flatMap((r, i) => (!r.success && deadToken.has(r.error?.code ?? '') ? [tokens[i]] : []));
    if (dead.length) await userRef.update({ fcmTokens: FieldValue.arrayRemove(...dead) });
    console.log(`Status diperbarui, ${res.successCount} dari ${tokens.length} push terkirim.`);
  } catch (e) {
    console.log(`Status diperbarui, tetapi push gagal dikirim: ${(e as Error).message}`);
  }
}

try {
  switch (command) {
    case 'inbox':
      await inbox();
      break;
    case 'status':
      await setStatus(positional[0], positional[1]);
      break;
    default:
      console.log('Pakai:\n  npm run recruiter -- inbox\n  npm run recruiter -- status <id> <tahap> [--note "..."] [--dry-run]');
      console.log(`Tahap: ${Object.keys(STAGES).join(', ')}`);
      process.exitCode = 1;
  }
} catch (e) {
  console.error((e as Error).message);
  process.exitCode = 1;
}
