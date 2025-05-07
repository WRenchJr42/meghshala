import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionService {
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  void subscribeToUserProfileChanges(Function(dynamic) onChange) {
    final channel = _supabaseClient.channel('public:user_profiles');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_profiles',
          callback: (payload) {
            onChange(payload);
          },
        )
        .subscribe();
  }
}
