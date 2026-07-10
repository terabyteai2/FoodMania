/// QuickBytes role model — three roles (spec §RBAC):
///   owner   — full access incl. Analytics, Settings, invite any role.
///   manager — live ops (Control Tower), stock/menu, messaging, invite waiter.
///   waiter  — floor only (Tables, Orders, More).
///
/// [isManager] is intentionally a *privilege gate* (owner OR manager) so the
/// many existing `isManager` checks (stock/menu edit, sync, POS settings,
/// messaging) keep working — owner is a superset of manager. Owner-only and
/// waiter-only distinctions use [isOwner] / [isWaiter].
enum AccountRole {
  owner,
  manager,
  waiter;

  String get value => name;

  String get label {
    switch (this) {
      case AccountRole.owner:
        return 'Owner';
      case AccountRole.manager:
        return 'Manager';
      case AccountRole.waiter:
        return 'Waiter';
    }
  }

  /// Bengali display label.
  String get labelBn {
    switch (this) {
      case AccountRole.owner:
        return 'মালিক';
      case AccountRole.manager:
        return 'ম্যানেজার';
      case AccountRole.waiter:
        return 'ওয়েটার';
    }
  }

  /// Elevated privileges — owner & manager. Used as the app-wide gate for
  /// stock/menu editing, cloud sync, POS settings and messaging.
  bool get isManager =>
      this == AccountRole.owner || this == AccountRole.manager;

  /// Owner-only privileges: Settings, full Analytics, inviting any role.
  bool get isOwner => this == AccountRole.owner;

  /// Floor-only role.
  bool get isWaiter => this == AccountRole.waiter;

  static AccountRole parse(String? value) {
    final normalized = value?.trim().toLowerCase();
    switch (normalized) {
      case 'owner':
        return AccountRole.owner;
      case 'waiter':
      case 'staff': // legacy alias
        return AccountRole.waiter;
      case 'manager':
        return AccountRole.manager;
      default:
        return AccountRole.manager;
    }
  }
}
