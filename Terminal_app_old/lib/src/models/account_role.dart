enum AccountRole {
  manager,
  staff;

  String get value => name;

  String get label {
    switch (this) {
      case AccountRole.manager:
        return 'Manager';
      case AccountRole.staff:
        return 'Staff';
    }
  }

  bool get isManager => this == AccountRole.manager;

  static AccountRole parse(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == 'staff') return AccountRole.staff;
    return AccountRole.manager;
  }
}
