import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountProfile {
  final String displayName;
  final String? gender;
  final int? birthYear;
  final int? birthMonth;
  final DateTime? updatedAt;

  const AccountProfile({
    required this.displayName,
    this.gender,
    this.birthYear,
    this.birthMonth,
    this.updatedAt,
  });

  AccountProfile copyWith({
    String? displayName,
    String? gender,
    int? birthYear,
    int? birthMonth,
    DateTime? updatedAt,
  }) {
    return AccountProfile(
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      birthMonth: birthMonth ?? this.birthMonth,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'display_name': displayName,
    'gender': gender,
    'birth_year': birthYear,
    'birth_month': birthMonth,
  };

  static AccountProfile fromJson(
    Map<String, dynamic> m, {
    DateTime? updatedAt,
  }) {
    return AccountProfile(
      displayName: (m['display_name'] ?? '').toString(),
      gender: m['gender']?.toString(),
      birthYear: (m['birth_year'] as num?)?.toInt(),
      birthMonth: (m['birth_month'] as num?)?.toInt(),
      updatedAt: updatedAt,
    );
  }
}

class AccountProfileService {
  static const int _encryptionVersion = 1;
  static const String _primaryTable = 'ledger_user_profiles';
  static const String _legacyTable = 'ledger_account_profiles';
  static const String _kAad = 'ledger_profile_v1';
  static const String _kHkdfSalt = 'ledger_app_profile_salt_v1';
  static const String _kHkdfInfo = 'ledger_profile_payload';
  static final AesGcm _aesGcm = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  final SupabaseClient _client;

  AccountProfileService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<AccountProfile?> loadCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final rows = await _selectProfileRows(user.id);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final ciphertext = (row['ciphertext'] ?? '').toString();
    if (ciphertext.isEmpty) return null;

    final plaintext = await _decryptPayload(user, ciphertext);
    final decoded = jsonDecode(plaintext) as Map<String, dynamic>;
    final updatedAtRaw = row['updated_at']?.toString();
    final updatedAt = updatedAtRaw == null
        ? null
        : DateTime.tryParse(updatedAtRaw)?.toLocal();
    return AccountProfile.fromJson(decoded, updatedAt: updatedAt);
  }

  Future<void> saveCurrentProfile(AccountProfile profile) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user');
    }
    final raw = jsonEncode(profile.toJson());
    final encrypted = await _encryptPayload(user, raw);
    await _saveProfileRow(user.id, <String, dynamic>{
      'user_id': user.id,
      'ciphertext': encrypted,
      'encryption_version': _encryptionVersion,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<dynamic>> _selectProfileRows(String userId) async {
    try {
      return await _client
          .from(_primaryTable)
          .select('ciphertext,updated_at')
          .eq('user_id', userId)
          .limit(1);
    } on PostgrestException catch (e) {
      if (!_isMissingTable(e)) rethrow;
      return await _client
          .from(_legacyTable)
          .select('ciphertext,updated_at')
          .eq('user_id', userId)
          .limit(1);
    }
  }

  Future<void> _saveProfileRow(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _client.from(_primaryTable).upsert(payload);
    } on PostgrestException catch (e) {
      if (!_isMissingTable(e)) rethrow;
      await _saveLegacyProfileRow(userId, payload);
    }
  }

  Future<void> _saveLegacyProfileRow(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    final row = await _client
        .from(_legacyTable)
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) {
      await _client.from(_legacyTable).insert(payload);
      return;
    }

    await _client.from(_legacyTable).update(payload).eq('user_id', userId);
  }

  bool _isMissingTable(PostgrestException e) {
    return e.code == 'PGRST205';
  }

  Future<String> _encryptPayload(User user, String plaintext) async {
    final key = await _deriveKey(user);
    final nonce = _randomNonce(12);
    final box = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
      aad: utf8.encode(_kAad),
    );
    return jsonEncode(<String, String>{
      'n': base64Encode(nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    });
  }

  Future<String> _decryptPayload(User user, String payload) async {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    final nonce = base64Decode((map['n'] ?? '').toString());
    final cipherText = base64Decode((map['c'] ?? '').toString());
    final macBytes = base64Decode((map['m'] ?? '').toString());
    final key = await _deriveKey(user);
    final clear = await _aesGcm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
      secretKey: key,
      aad: utf8.encode(_kAad),
    );
    return utf8.decode(clear);
  }

  Future<SecretKey> _deriveKey(User user) {
    final source = utf8.encode(
      'uid:${user.id}|aud:${_client.auth.currentSession?.user.aud ?? 'authenticated'}|pepper:ledger_profile_pepper_v1',
    );
    return _hkdf.deriveKey(
      secretKey: SecretKey(source),
      nonce: utf8.encode(_kHkdfSalt),
      info: utf8.encode(_kHkdfInfo),
    );
  }

  Uint8List _randomNonce(int length) {
    final r = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => r.nextInt(256)),
    );
  }
}
