import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend.dart';
import '../mock_data.dart';
import 'application_repository.dart';
import 'auth_repository.dart';
import 'job_repository.dart';
import 'profile_repository.dart';
import 'user_repository.dart';

/// The user id the mock backend uses in place of a signed-in account.
const mockUid = 'demo';

/// The build-time [backend]; tests override it to run the Firebase sync logic against mock repositories.
final backendProvider = Provider<Backend>((_) => backend);

T _pick<T>({required T Function() mock, required T Function() firebase}) => switch (backend) {
  Backend.mock => mock(),
  Backend.firebase => firebase(),
};

final authRepositoryProvider = Provider<AuthRepository>((_) => _pick(mock: MockAuthRepository.new, firebase: FirebaseAuthRepository.new));

final userRepositoryProvider = Provider<UserRepository>((_) => _pick(mock: MockUserRepository.new, firebase: FirestoreUserRepository.new));

final jobRepositoryProvider = Provider<JobRepository>((_) => _pick(mock: MockJobRepository.new, firebase: FirestoreJobRepository.new));

final profileRepositoryProvider = Provider<ProfileRepository>(
  (_) => _pick(mock: MockProfileRepository.new, firebase: FirestoreProfileRepository.new),
);

/// Firebase implementation arrives in Tahap B3; until then `BACKEND=firebase` fails loudly instead of silently using mocks.
final applicationRepositoryProvider = Provider<ApplicationRepository>(
  (_) => _pick(
    mock: () => MockApplicationRepository({mockUid: initialApplications}),
    firebase: () => throw UnimplementedError('Repository lamaran Firebase dibuat pada Tahap B3.'),
  ),
);
