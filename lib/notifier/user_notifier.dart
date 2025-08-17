import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../network/api/api_response.dart';

class UserAsyncNotifier extends FamilyAsyncNotifier<User, int> {
  @override
  Future<User> build(int userId) async {
    print('🧠 UserAsyncNotifier: Loading user #$userId...');

    final response = await ModernJSONPlaceholderService.getUser(userId);

    return switch (response) {
      ApiSuccess<User>(data: final user) => () {
        print('✅ Successfully loaded user: ${user.displayName}');
        return user;
      }(),

      ApiError<User>(message: final message, type: final type) => () {
        print('❌ Failed to load user #$userId: $message');

        throw switch (type) {
          NetworkErrorType.notFound => Exception('User #$userId not found'),
          NetworkErrorType.noConnection => Exception('No internet connection'),
          _ => Exception('Failed to load user: $message'),
        };
      }(),
    };
  }

  // Update user info (for demo purposes)
  Future<void> updateUser({
    String? name,
    String? email,
    String? phone,
  }) async {
    final currentUser = state.value;
    if (currentUser == null) return;

    print('✏️ Updating user #$arg info...');

    // In a real app, you would make a PATCH/PUT request here
    // For demo, we'll just update locally

    final updatedUser = User(
      id: currentUser.id,
      name: name ?? currentUser.name,
      username: currentUser.username,
      email: email ?? currentUser.email,
      phone: phone ?? currentUser.phone,
      website: currentUser.website,
      address: currentUser.address,
      company: currentUser.company,
    );

    state = AsyncValue.data(updatedUser);
  }
}

// Family provider for individual users
final userProvider = AsyncNotifierProvider.family<UserAsyncNotifier, User, int>(() {
  return UserAsyncNotifier();
});

// All users provider
class UsersAsyncNotifier extends AsyncNotifier<List<User>> {
  @override
  Future<List<User>> build() async {
    print('🧠 UsersAsyncNotifier: Loading all users...');

    final response = await ModernJSONPlaceholderService.getUsers();

    return switch (response) {
      ApiSuccess<List<User>>(data: final users) => () {
        print('✅ Successfully loaded ${users.length} users');
        return users;
      }(),

      ApiError<List<User>>(message: final message) => () {
        print('❌ Failed to load users: $message');
        throw Exception('Failed to load users: $message');
      }(),
    };
  }
}

final usersProvider = AsyncNotifierProvider<UsersAsyncNotifier, List<User>>(() {
  return UsersAsyncNotifier();
});
