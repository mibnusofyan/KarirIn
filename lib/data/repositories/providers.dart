import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend.dart';
import '../mock_data.dart';
import 'application_repository.dart';
import '../../services/ai/ai_service.dart';
import '../../services/cv_storage.dart';
import '../../services/network.dart';
import '../../services/push.dart';
import '../../services/reminders.dart';
import 'activity_repository.dart';
import 'auth_repository.dart';
import 'interview_repository.dart';
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

final applicationRepositoryProvider = Provider<ApplicationRepository>(
  (_) => _pick<ApplicationRepository>(
    mock: () => MockApplicationRepository({mockUid: initialApplications}),
    firebase: FirestoreApplicationRepository.new,
  ),
);

final activityRepositoryProvider = Provider<ActivityRepository>(
  (_) => _pick<ActivityRepository>(mock: MockActivityRepository.new, firebase: FirestoreActivityRepository.new),
);

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (_) => _pick<ReminderScheduler>(mock: () => const NoopReminderScheduler(), firebase: LocalReminderScheduler.new),
);

final interviewRepositoryProvider = Provider<InterviewRepository>(
  (_) => _pick(mock: MockInterviewRepository.new, firebase: FirestoreInterviewRepository.new),
);

/// Gemini (with the local logic as fallback) on Firebase builds; the prototype's local logic on mock builds.
final aiServiceProvider = Provider<AiService>(
  (_) => _pick<AiService>(mock: () => const OfflineAiService(), firebase: () => ResilientAiService(GeminiAiService())),
);

final cvStorageProvider = Provider<CvStorage>((_) => const CvStorage());

final networkStatusProvider = Provider<NetworkStatus>(
  (_) => _pick<NetworkStatus>(mock: () => const NoNetworkStatus(), firebase: DeviceNetworkStatus.new),
);

final pushServiceProvider = Provider<PushService>(
  (ref) => _pick<PushService>(mock: () => const NoopPushService(), firebase: () => FcmPushService(ref.read(reminderSchedulerProvider))),
);
