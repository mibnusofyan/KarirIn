import '../mock_data.dart' as mock;
import '../models.dart';

/// Curated catalogue: `jobs` and `skills` in Firestore, written only by the team's seed script.
abstract interface class JobRepository {
  Future<List<Job>> fetchJobs();
  Future<List<Skill>> fetchSkills();
}

class MockJobRepository implements JobRepository {
  const MockJobRepository();

  @override
  Future<List<Job>> fetchJobs() async => mock.jobs;

  @override
  Future<List<Skill>> fetchSkills() async => mock.skillCatalog;
}
