// The TypeScript Match Score must equal the Dart one on the shared fixtures (test/fixtures/match_cases.json).
import { readFileSync } from 'node:fs';
import { describe, expect, test } from 'vitest';
import { ANY_CITY, formatScore, matchScore, type Job, type Profile } from '../src/match-score.js';

const fixtures = JSON.parse(readFileSync(new URL('../../test/fixtures/match_cases.json', import.meta.url), 'utf8')) as {
  jobs: Record<string, Job>;
  profiles: Record<string, Profile>;
  cases: { profile: string; jobId: string; total: number }[];
};
const jobs = fixtures.jobs;

describe('Match Score TypeScript = Dart', () => {
  test.each(fixtures.cases)('$profile × $jobId = $total', ({ profile, jobId, total }) => {
    expect(matchScore(jobs[jobId], fixtures.profiles[profile])).toBeCloseTo(total, 3);
  });

  test('"Seluruh Indonesia" cocok untuk kota mana pun', () => {
    const nationwide = Object.values(jobs).find((j) => j.city === ANY_CITY && j.mode !== 'remote')!;
    const rani = fixtures.profiles.rani;
    expect(matchScore(nationwide, { ...rani, city: 'Kota Lain' })).toBe(matchScore(nationwide, rani));
    expect(matchScore({ ...nationwide, city: 'Kota Lain' }, rani)).toBeLessThan(matchScore(nationwide, rani));
  });

  test('Tabel 2.4: Rani 80 → 92,5', () => {
    expect(formatScore(matchScore(jobs.j1, fixtures.profiles.rani))).toBe('80');
    expect(formatScore(matchScore(jobs.j1, fixtures.profiles['rani-pelaporan']))).toBe('92,5');
  });
});
