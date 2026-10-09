import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend.dart';
import '../mock_data.dart';
import 'application_repository.dart';
import 'job_repository.dart';
import 'profile_repository.dart';

/// The user id the mock backend uses in place of a signed-in account.
const mockUid = 'demo';

/// Firebase implementations arrive in Tahap B1; until then `BACKEND=firebase` fails loudly instead of silently using mocks.
T _pick<T>(T mock) => switch (backend) {
  Backend.mock => mock,
  Backend.firebase => throw UnimplementedError('Repository Firebase dibuat pada Tahap B1.'),
};

final jobRepositoryProvider = Provider<JobRepository>((_) => _pick<JobRepository>(const MockJobRepository()));

final profileRepositoryProvider = Provider<ProfileRepository>((_) => _pick<ProfileRepository>(MockProfileRepository()));

final applicationRepositoryProvider = Provider<ApplicationRepository>(
  (_) => _pick<ApplicationRepository>(MockApplicationRepository({mockUid: initialApplications})),
);
