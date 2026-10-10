// The TypeScript Match Score must equal the Dart one on the shared fixtures (test/fixtures/match_cases.json).
import { readFileSync } from 'node:fs';
import { describe, expect, test } from 'vitest';
import { formatScore, matchScore, type Job, type Profile } from '../src/match-score.js';

const fixtures = JSON.parse(readFileSync(new URL('../../test/fixtures/match_cases.json', import.meta.url), 'utf8')) as {
  profiles: Record<string, Profile>;
  cases: { profile: string; jobId: string; total: number }[];
};
const jobs = Object.fromEntries(
  (JSON.parse(readFileSync(new URL('../data/jobs.json', import.meta.url), 'utf8')) as (Job & { id: string })[]).map((j) => [j.id, j]),
);

describe('Match Score TypeScript = Dart', () => {
  test.each(fixtures.cases)('$profile × $jobId = $total', ({ profile, jobId, total }) => {
    expect(matchScore(jobs[jobId], fixtures.profiles[profile])).toBeCloseTo(total, 3);
  });

  test('Tabel 2.4: Rani 80 → 92,5', () => {
    expect(formatScore(matchScore(jobs.j1, fixtures.profiles.rani))).toBe('80');
    expect(formatScore(matchScore(jobs.j1, fixtures.profiles['rani-pelaporan']))).toBe('92,5');
  });
});
