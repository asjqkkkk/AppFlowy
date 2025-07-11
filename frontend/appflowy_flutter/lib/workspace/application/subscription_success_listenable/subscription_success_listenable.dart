import 'package:appflowy_backend/log.dart';
import 'package:flutter/foundation.dart';

import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';

class SubscriptionSuccessListenable extends ChangeNotifier {
  SubscriptionSuccessListenable();

  String? _plan;

  SubscriptionPlanPB? get workspaceSubscriptionPlan => switch (_plan) {
        'free' => SubscriptionPlanPB.Free,
        'pro' => SubscriptionPlanPB.Pro,
        'team' => SubscriptionPlanPB.Team,
        'ai_max' => SubscriptionPlanPB.AiMax,
        'ai_local' => SubscriptionPlanPB.AiLocal,
        _ => null,
      };

  PersonalPlanPB? get personalSubscriptionPlan => switch (_plan) {
        'vault_workspace' => PersonalPlanPB.VaultWorkspace,
        _ => null,
      };

  void onPaymentSuccess(String? plan) {
    Log.info("Payment success: $plan");
    _plan = plan;
    notifyListeners();
  }
}
