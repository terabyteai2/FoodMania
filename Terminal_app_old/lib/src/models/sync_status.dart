enum SyncStatus {
  synced,
  pending,
  failed;

  String get value => name;

  String get label {
    switch (this) {
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.pending:
        return 'Pending';
      case SyncStatus.failed:
        return 'Failed';
    }
  }

  static SyncStatus parse(
    String? value, {
    SyncStatus fallback = SyncStatus.synced,
  }) {
    if (value == null) return fallback;
    final normalized = value.trim().toLowerCase();
    for (final status in SyncStatus.values) {
      if (status.value == normalized) return status;
    }
    return fallback;
  }
}
