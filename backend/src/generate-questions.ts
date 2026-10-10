// Interview question sets per job (proposal 2.2.1 and 3.1.3): Gemini drafts 3 behavioural and 2 technical
// questions from the job description, the team reviews them, and only reviewed sets reach the app.
//
//   npm run questions -- draft [jobId ...]   → backend/data/questions/<jobId>.json (needs GEMINI_API_KEY)
//   (review each file: fix wording, remove anything inappropriate, then set "reviewedBy" to your name)
//   npm run questions -- publish             → jobs/{id}/questionSets in Firestore (reviewed files only)
//
// Drafting uses a Gemini API key from Google AI Studio (free tier); it never ships in the app.
import { mkdir, readdir, readFile, writeFile } from 'node:fs/promises';
import { GoogleGenAI, Type } from '@google/genai';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

try {
  process.loadEnvFile(new URL('../.env', import.meta.url));
} catch {
  // Variables may come from the shell instead.
}

type Job = { id: string; title: string; company: string; desc: string; wajib: string[]; tambahan: string[] };
type Question = { type: 'Perilaku' | 'Teknis'; text: string; demo: string; better: string };
type QuestionSet = { jobId: string; jobTitle: string; model: string; reviewedBy: string | null; questions: Question[] };

const dir = new URL('../data/questions/', import.meta.url);
const jobs = JSON.parse(await readFile(new URL('../data/jobs.json', import.meta.url), 'utf8')) as Job[];

function prompt(job: Job): string {
  return `Kamu adalah pewawancara profesional di Indonesia. Susun 5 pertanyaan latihan wawancara kerja untuk lowongan berikut.

Lowongan: ${job.title} di ${job.company}
Deskripsi: ${job.desc}
Keterampilan wajib: ${job.wajib.join(', ')}
Keterampilan tambahan: ${job.tambahan.join(', ')}

Aturan:
- Tepat 3 pertanyaan "Perilaku" (pengalaman masa lalu, cocok dijawab dengan pola STAR) lalu 2 pertanyaan "Teknis" tentang keterampilan wajib.
- Kandidat adalah lulusan baru SMA/SMK/D3/S1; pengalaman magang, PKL, organisasi, dan proyek sekolah boleh dipakai.
- Bahasa Indonesia yang wajar, sapa kandidat dengan "kamu". Satu pertanyaan maksimal 30 kata.
- Dilarang bertanya tentang agama, suku, status pernikahan, rencana punya anak, kesehatan, usia, atau penampilan.
- demo: contoh jawaban biasa-biasa saja dari kandidat (2–3 kalimat, kurang detail dan tanpa angka).
- better: contoh jawaban yang baik (60–100 kata, orang pertama, pola STAR, ada hasil terukur).`;
}

const schema = {
  type: Type.OBJECT,
  properties: {
    questions: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          type: { type: Type.STRING, enum: ['Perilaku', 'Teknis'] },
          text: { type: Type.STRING },
          demo: { type: Type.STRING },
          better: { type: Type.STRING },
        },
        required: ['type', 'text', 'demo', 'better'],
      },
    },
  },
  required: ['questions'],
};

function check(set: QuestionSet): string | null {
  const qs = set.questions;
  if (qs.length !== 5) return 'harus tepat 5 pertanyaan';
  if (qs.filter((q) => q.type === 'Perilaku').length !== 3) return 'harus 3 pertanyaan Perilaku dan 2 Teknis';
  if (qs.some((q) => !q.text?.trim() || !q.better?.trim())) return 'ada pertanyaan atau contoh jawaban yang kosong';
  const banned = /\b(agama|suku|menikah|pernikahan|hamil|anak|kesehatan|penyakit|usia|umur|penampilan)\b/i;
  const hit = qs.find((q) => banned.test(q.text));
  return hit ? `pertanyaan berpotensi diskriminatif: "${hit.text}"` : null;
}

async function draft(ids: string[]) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error('GEMINI_API_KEY belum diisi (lihat backend/.env.example).');
  const model = process.env.GEMINI_MODEL ?? 'gemini-3.8-flash';
  const ai = new GoogleGenAI({ apiKey });
  await mkdir(dir, { recursive: true });
  for (const job of jobs.filter((j) => ids.length === 0 || ids.includes(j.id))) {
    const res = await ai.models.generateContent({
      model,
      contents: prompt(job),
      config: { temperature: 0.6, responseMimeType: 'application/json', responseSchema: schema },
    });
    const questions = (JSON.parse(res.text ?? '{}') as { questions?: Question[] }).questions ?? [];
    // Behavioural first, as the app numbers them.
    questions.sort((a, b) => (a.type === b.type ? 0 : a.type === 'Perilaku' ? -1 : 1));
    const set: QuestionSet = { jobId: job.id, jobTitle: job.title, model, reviewedBy: null, questions };
    const problem = check(set);
    await writeFile(new URL(`${job.id}.json`, dir), `${JSON.stringify(set, null, 2)}\n`);
    console.log(`${job.id} ${job.title}: ${problem ? `PERIKSA (${problem})` : 'draf siap ditinjau'}`);
  }
}

async function publish() {
  const projectId = process.env.GCLOUD_PROJECT;
  if (!projectId) throw new Error('GCLOUD_PROJECT belum diisi (lihat backend/.env.example).');
  initializeApp(process.env.FIRESTORE_EMULATOR_HOST ? { projectId } : { projectId, credential: applicationDefault() });
  const db = getFirestore();
  const files = (await readdir(dir).catch(() => [])).filter((f) => f.endsWith('.json'));
  let published = 0;
  for (const f of files) {
    const set = JSON.parse(await readFile(new URL(f, dir), 'utf8')) as QuestionSet;
    const problem = check(set);
    if (!set.reviewedBy || problem) {
      console.log(`${set.jobId}: dilewati (${problem ?? 'belum ditinjau; isi "reviewedBy"'})`);
      continue;
    }
    await db.collection('jobs').doc(set.jobId).collection('questionSets').add({
      questions: set.questions,
      model: set.model,
      reviewedBy: set.reviewedBy,
      createdAt: FieldValue.serverTimestamp(),
    });
    published++;
  }
  console.log(`${published} set pertanyaan diterbitkan ke ${projectId}.`);
}

const [command, ...ids] = process.argv.slice(2);
if (command === 'draft') await draft(ids);
else if (command === 'publish') await publish();
else console.log('Pakai: npm run questions -- draft [jobId ...] | publish');
