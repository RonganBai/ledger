String maskEmail(String email) {
  final trimmed = email.trim();
  final at = trimmed.indexOf('@');
  if (at <= 0 || at >= trimmed.length - 1) return trimmed;

  final local = trimmed.substring(0, at);
  final domain = trimmed.substring(at);
  if (local.length <= 2) {
    return '${local[0]}*${local.length == 2 ? local[1] : ''}$domain';
  }

  final visiblePrefix = local.substring(0, 1);
  final visibleSuffix = local.substring(local.length - 1);
  final masked = '*' * (local.length - 2);
  return '$visiblePrefix$masked$visibleSuffix$domain';
}

String resolveDisplayName({
  required String? displayName,
  required String? email,
}) {
  final name = (displayName ?? '').trim();
  if (name.isNotEmpty) return name;
  return maskEmail(email ?? '');
}
