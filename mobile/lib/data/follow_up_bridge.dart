/// Lightweight handoff: Profile → Plan tab for SOS re-check linked to a parent.
class FollowUpBridge {
  FollowUpBridge._();

  static int? parentCheckId;
  static String? homeCity;
  static String? destCity;

  static void arm({
    required int parentId,
    String home = '',
    String dest = '',
  }) {
    parentCheckId = parentId;
    homeCity = home;
    destCity = dest;
  }

  static ({int parentId, String home, String dest})? take() {
    final id = parentCheckId;
    if (id == null) return null;
    final home = homeCity ?? '';
    final dest = destCity ?? '';
    parentCheckId = null;
    homeCity = null;
    destCity = null;
    return (parentId: id, home: home, dest: dest);
  }
}
