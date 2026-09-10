import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/expense_sales_log.dart';
import '../models/poultry_log.dart';
import '../models/flock.dart';
import '../models/supplier.dart';
import 'poultry_calculation_service.dart';
import 'expense_category_config.dart';
import 'farm_config.dart';
import 'cashew_migration_parser.dart';

/// Firebase-only data layer for the Spark-plan architecture.
///
/// Business calculations are performed client-side, while Firestore Rules
/// enforce ownership, field shape, non-negative values, and calculated-field
/// invariants. Daily-log documents use deterministic date IDs so duplicates
/// are impossible at the document level.
class CashewImportResult {
  final int imported;
  final int updated;
  final int unchanged;

  const CashewImportResult({this.imported = 0, this.updated = 0, this.unchanged = 0});

  int get total => imported + updated + unchanged;
}

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Future<void>? _googleSignInInitialization;
  bool get isSignedIn => currentUser != null;
  Stream<User?> get authChanges => _auth.authStateChanges();

  String? _activeFlockId;
  String? get activeFlockId => _activeFlockId;

  String get _uid {
    final user = currentUser;
    if (user == null) throw StateError('Please sign in first.');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _flocks => _db.collection('flocks');
  CollectionReference<Map<String, dynamic>> get _memberships => _db.collection('users').doc(_uid).collection('flock_memberships');

  void setActiveFlock(String flockId) {
    if (flockId.trim().isEmpty) throw ArgumentError('Flock ID cannot be empty.');
    _activeFlockId = flockId;
  }

  String get _flockId {
    final id = _activeFlockId;
    if (id == null || id.isEmpty) throw StateError('Select a flock first.');
    return id;
  }

  DocumentReference<Map<String, dynamic>> get _flock => _flocks.doc(_flockId);
  CollectionReference<Map<String, dynamic>> get _daily => _flock.collection('daily_logs');
  CollectionReference<Map<String, dynamic>> get _expenses => _flock.collection('expense_records');
  DocumentReference<Map<String, dynamic>> get _farmConfig => _flock;

  Future<bool> ensureUserProfile() async {
    final user = currentUser;
    if (user == null) throw StateError('Please sign in first.');

    final ref = _db.collection('users').doc(_uid).collection('profile').doc('account');
    final snap = await ref.get();

    // Authorization is stored in Firestore; the app never promotes a user
    // based on a hard-coded UID.
    if (snap.exists) return snap.data()?['role'] == 'admin';

    final email = user.email?.trim().toLowerCase() ?? '';
    var invited = false;
    if (email.isNotEmpty) {
      final invites = await _db.collectionGroup('invitations')
          .where('email', isEqualTo: email)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      invited = invites.docs.isNotEmpty;
    }

    // A normal user must never be promoted to admin just because they are
    // the first account seen by this device. Invited users become members.
    if (invited) {
      await ref.set({
        'email': user.email ?? '',
        'displayName': user.displayName ?? user.email ?? 'User',
        'role': 'member',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return false;
    }

    // No profile and no invitation: remain a normal authenticated user with
    // no flock access until an admin invites the registered email.
    return false;
  }

  Future<bool> isAdmin() async {
    final snap = await _db.collection('users').doc(_uid).collection('profile').doc('account').get();
    return snap.exists && snap.data()?['role'] == 'admin';
  }

  Future<bool> isFlockMember(String flockId) async {
    if (_uid.isEmpty || flockId.trim().isEmpty) return false;
    final membership = await _flocks
        .doc(flockId.trim())
        .collection('members')
        .doc(_uid)
        .get();
    if (!membership.exists) return false;
    final role = membership.data()?['role']?.toString().trim().toLowerCase();
    return role == 'admin' || role == 'member';
  }

  Future<List<Flock>> fetchFlocks() async {
    // Admin startup must not depend on the invitation collection-group query.
    // Existing admins can already access flock documents directly, and the
    // migration creates/repairs their flock memberships below. This avoids a
    // permission-denied failure in the startup path before the flock can be
    // selected.
    final admin = await isAdmin();
    if (admin) {
      final snap = await _flocks.get();
      final result = snap.docs
          .map((d) => Flock.fromFirestore(d.id, d.data()))
          .toList();
      result.sort((a, b) => b.startDate.compareTo(a.startDate));

      final user = currentUser;
      final membership = {
        'role': 'admin',
        'email': user?.email ?? '',
        'displayName': user?.displayName ?? user?.email ?? 'Admin',
        'mobileNumber': '',
        'notificationLanguage': 'en',
      };

      // Repair both sides of the membership mapping. This is idempotent and
      // uses the actual Firestore role, never a hard-coded UID.
      for (final flock in result) {
        final memberRef = _flocks.doc(flock.id).collection('members').doc(_uid);
        final memberSnap = await memberRef.get();
        if (!memberSnap.exists || memberSnap.data()?['role'] != 'admin') {
          await memberRef.set(membership, SetOptions(merge: true));
        }

        final userMembership = _memberships.doc(flock.id);
        final userMembershipSnap = await userMembership.get();
        if (!userMembershipSnap.exists || userMembershipSnap.data()?['role'] != 'admin') {
          await userMembership.set({...membership, 'flockId': flock.id}, SetOptions(merge: true));
        }
      }

      // The legacy-to-flock migration is intentionally only a fallback for a
      // single flock. The dedicated one-time migration handles the historical
      // Amzad data, so this path does not create a second flock.
      if (result.length == 1) {
        await _migrateLegacyRecordsToFlockIfNeeded(result.first.id);
      }
      return result;
    }

    await _claimPendingInvitations();
    final current = await _memberships.get();
    final ids = current.docs.map((d) => d.id).toList();
    if (ids.isEmpty) return [];
    final result = <Flock>[];
    for (var start = 0; start < ids.length; start += 10) {
      final chunk = ids.sublist(start, (start + 10 < ids.length) ? start + 10 : ids.length);
      final snap = await _flocks.where(FieldPath.documentId, whereIn: chunk).get();
      result.addAll(snap.docs.map((d) => Flock.fromFirestore(d.id, d.data())));
    }
    result.sort((a, b) => b.startDate.compareTo(a.startDate));
    return result;
  }

  Future<Flock?> fetchFlock(String flockId) async {
    final snap = await _flocks.doc(flockId).get();
    return snap.exists ? Flock.fromFirestore(snap.id, snap.data() ?? const {}) : null;
  }

  Future<void> _migrateLegacyRecordsToFlockIfNeeded(String flockId) async {
    final flockRef = _flocks.doc(flockId);
    final markerRef = flockRef.collection('migration').doc('legacy_user_data');
    final marker = await markerRef.get();
    if (marker.exists) return;

    final targetLogs = await flockRef.collection('daily_logs').limit(1).get();
    final targetExpenses = await flockRef.collection('expense_records').limit(1).get();
    final legacyLogs = await _db.collection('users').doc(_uid).collection('daily_logs').get();
    final legacyExpenses = await _db.collection('users').doc(_uid).collection('expense_records').get();

    final shouldCopyLogs = targetLogs.docs.isEmpty && legacyLogs.docs.isNotEmpty;
    final shouldCopyExpenses = targetExpenses.docs.isEmpty && legacyExpenses.docs.isNotEmpty;

    if (!shouldCopyLogs && !shouldCopyExpenses) {
      await markerRef.set({
        'completedAt': FieldValue.serverTimestamp(),
        'legacyLogsFound': legacyLogs.docs.length,
        'legacyExpensesFound': legacyExpenses.docs.length,
        'copied': false,
      });
      return;
    }

    var batch = _db.batch();
    var count = 0;
    var copiedLogs = 0;
    var copiedExpenses = 0;
    var skipped = 0;

    Future<void> commitIfNeeded() async {
      if (count < 400) return;
      await batch.commit();
      batch = _db.batch();
      count = 0;
    }

    if (shouldCopyLogs) {
      for (final doc in legacyLogs.docs) {
        try {
          final log = PoultryLog.fromFirestore(doc.data());
          final data = log.toFirestore();
          // Keep the historical creator when present.
          final old = doc.data();
          if (old['createdByUid'] is String) data['createdByUid'] = old['createdByUid'];
          if (old['createdByName'] is String) data['createdByName'] = old['createdByName'];
          if (old['createdAt'] is Timestamp) data['createdAt'] = old['createdAt'];
          batch.set(flockRef.collection('daily_logs').doc(doc.id), data);
          copiedLogs++;
          count++;
          await commitIfNeeded();
        } catch (_) {
          skipped++;
        }
      }
    }

    if (shouldCopyExpenses) {
      for (final doc in legacyExpenses.docs) {
        try {
          final record = ExpenseSalesLog.fromFirestore(doc.data(), id: doc.id);
          final data = record.toFirestore();
          final old = doc.data();
          if (old['createdByUid'] is String) data['createdByUid'] = old['createdByUid'];
          if (old['createdByName'] is String) data['createdByName'] = old['createdByName'];
          if (old['createdAt'] is Timestamp) data['createdAt'] = old['createdAt'];
          batch.set(flockRef.collection('expense_records').doc(doc.id), data);
          copiedExpenses++;
          count++;
          await commitIfNeeded();
        } catch (_) {
          skipped++;
        }
      }
    }

    if (count > 0) await batch.commit();

    // Mark the migration complete so successful records are never copied
    // again. Skipped malformed legacy records remain in their original
    // location and do not block the application from starting.
    await markerRef.set({
      'completedAt': FieldValue.serverTimestamp(),
      'legacyLogsFound': legacyLogs.docs.length,
      'legacyExpensesFound': legacyExpenses.docs.length,
      'copiedLogs': copiedLogs,
      'copiedExpenses': copiedExpenses,
      'skipped': skipped,
      'copied': copiedLogs > 0 || copiedExpenses > 0,
    });
  }

  Future<String> createFlock({required String name, required DateTime startDate, required int startingBirds, required String breedName, required List<String> accounts, required List<String> feedItems}) async {
    if (!await isAdmin()) throw StateError('Only an admin can create a flock.');

    // Only running flocks count toward the three-flock limit. Ended flocks
    // are historical records and can be kept without limit.
    final existing = await _flocks.get();
    final runningCount = existing.docs.where((doc) => doc.data()['endDate'] == null).length;
    if (runningCount >= 3) {
      throw StateError('You can have a maximum of 3 running flocks.');
    }

    final ref = _flocks.doc();
    final user = currentUser;
    final data = Flock(id: ref.id, name: name, startDate: startDate, endDate: null, startingBirds: startingBirds, breedName: breedName, accounts: accounts, feedItems: feedItems, createdByUid: user?.uid ?? '').toFirestore();
    data['state'] = 'running';
    await ref.set(data);
    await ref.collection('members').doc(_uid).set({'role': 'admin', 'email': user?.email ?? '', 'displayName': user?.displayName ?? user?.email ?? 'Admin', 'mobileNumber':'', 'notificationLanguage':'en'});
    await _memberships.doc(ref.id).set({'role': 'admin', 'email': user?.email ?? '', 'displayName': user?.displayName ?? user?.email ?? 'Admin', 'mobileNumber':'', 'notificationLanguage':'en'});
    return ref.id;
  }

  Future<void> updateFlock(Flock flock) async {
    if (!await isAdmin()) throw StateError('Only an admin can configure flocks.');
    if (flock.endDate == null) {
      final existing = await _flocks.get();
      final runningCount = existing.docs.where((doc) => doc.id != flock.id && doc.data()['endDate'] == null).length;
      if (runningCount >= 3) {
        throw StateError('You can have a maximum of 3 running flocks.');
      }
    }
    final data = flock.toFirestore();
    data['state'] = flock.endDate == null ? 'running' : 'ended';
    await _flocks.doc(flock.id).set(data, SetOptions(merge: true));
  }

  Future<void> endFlock(String flockId, DateTime endDate) async {
    if (!await isAdmin()) throw StateError('Only an admin can end a flock.');
    await _flocks.doc(flockId).update({'endDate': Timestamp.fromDate(DateTime(endDate.year, endDate.month, endDate.day)), 'state': 'ended', 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<List<FlockMembership>> fetchMembers(String flockId) async {
    final snap = await _flocks.doc(flockId).collection('members').get();
    return snap.docs.map((d) => FlockMembership.fromFirestore(flockId, d.data(), uid: d.id)).toList();
  }

  Future<int> syncInvitedMembers(String flockId) async {
    if (!await isAdmin()) throw StateError('Only an admin can synchronize members.');
    final invites = await _flocks.doc(flockId).collection('invitations')
        .where('status', isEqualTo: 'pending').get();
    var synced = 0;
    for (final invite in invites.docs) {
      final data = invite.data();
      final email = data['email']?.toString().trim().toLowerCase() ?? '';
      if (email.isEmpty) continue;

      // Firebase Authentication users cannot be listed from a client app.
      // The app profile created after sign-in is the safe Firestore-side
      // bridge from the invited email address to the authenticated UID.
      final profiles = await _db.collectionGroup('profile')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (profiles.docs.isEmpty) continue;

      final profileDoc = profiles.docs.first;
      final userRef = profileDoc.reference.parent.parent;
      if (userRef == null) continue;
      final uid = userRef.id;
      final profile = profileDoc.data();
      final membership = {
        'role': 'member',
        'email': email,
        'displayName': profile['displayName']?.toString() ?? email,
        'mobileNumber': profile['mobileNumber']?.toString() ?? '',
        'notificationLanguage': profile['notificationLanguage']?.toString() == 'hi' ? 'hi' : 'en',
      };
      await _flocks.doc(flockId).collection('members').doc(uid).set(membership, SetOptions(merge: true));
      await _db.collection('users').doc(uid).collection('flock_memberships').doc(flockId).set(
        {...membership, 'flockId': flockId}, SetOptions(merge: true));
      await invite.reference.update({
        'status': 'accepted',
        'acceptedByUid': uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      synced++;
    }
    return synced;
  }

  Stream<List<FlockMembership>> watchMembers(String flockId) {
    return _flocks.doc(flockId).collection('members').snapshots().map((snap) {
      final members = snap.docs
          .map((d) => FlockMembership.fromFirestore(flockId, d.data(), uid: d.id))
          .toList();
      members.sort((a, b) {
        final aName = (a.displayName.isEmpty ? a.email : a.displayName).toLowerCase();
        final bName = (b.displayName.isEmpty ? b.email : b.displayName).toLowerCase();
        return aName.compareTo(bName);
      });
      return members;
    });
  }

  Future<void> inviteMember({required String flockId, required String email}) async {
    if (!await isAdmin()) throw StateError('Only an admin can add members.');
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) throw StateError('Enter a registered email address.');
    await _flocks.doc(flockId).collection('invitations').doc(normalized).set({
      'email': normalized,
      'status': 'pending',
      'createdByUid': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> fetchNotificationSettings(String flockId) async {
    if (!await isAdmin()) throw StateError('Only an admin can configure notifications.');
    final snap = await _flocks.doc(flockId).collection('notification_settings').doc('config').get();
    return snap.data();
  }

  Future<void> saveNotificationSettings(String flockId, Map<String, dynamic> data) async {
    if (!await isAdmin()) throw StateError('Only an admin can configure notifications.');
    await _flocks.doc(flockId).collection('notification_settings').doc('config').set(data, SetOptions(merge: true));
  }

  Future<void> saveNotificationTemplate(String flockId, String templateId, Map<String, dynamic> data) async {
    if (!await isAdmin()) throw StateError('Only an admin can configure notifications.');
    await _flocks.doc(flockId).collection('notification_templates').doc(templateId).set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> fetchNotificationTemplate(String flockId, String templateId) async {
    if (!await isAdmin()) throw StateError('Only an admin can configure notifications.');
    final snap = await _flocks.doc(flockId).collection('notification_templates').doc(templateId).get();
    return snap.data();
  }

  Future<void> sendFlockNotification({required String flockId, required String titleEn, required String titleHi, required String bodyEn, required String bodyHi, String? memberUid}) async {
    if (!await isAdmin()) throw StateError('Only an admin can send notifications.');
    await _flocks.doc(flockId).collection('notification_requests').add({
      'type':'manual', 'titleEn':titleEn, 'titleHi':titleHi, 'bodyEn':bodyEn, 'bodyHi':bodyHi,
      'memberUid':memberUid, 'createdByUid':_uid, 'createdAt':FieldValue.serverTimestamp(), 'status':'pending',
    });
  }

  Future<void> updateMemberDetails(String flockId, String memberUid, {String? mobileNumber, String? notificationLanguage}) async {
    if (!await isAdmin()) throw StateError('Only an admin can update member details.');
    final data=<String,dynamic>{};
    if (mobileNumber != null) data['mobileNumber']=mobileNumber.trim();
    if (notificationLanguage != null) data['notificationLanguage']=notificationLanguage == 'hi' ? 'hi' : 'en';
    if (data.isEmpty) return;
    await _flocks.doc(flockId).collection('members').doc(memberUid).set(data, SetOptions(merge:true));
    await _db.collection('users').doc(memberUid).collection('flock_memberships').doc(flockId).set(data, SetOptions(merge:true));
  }

  Future<void> updateMemberRole(String flockId, String memberUid, String role) async {
    if (!await isAdmin()) throw StateError('Only an admin can manage roles.');
    if (role != 'admin' && role != 'member') throw ArgumentError('Invalid role.');
    if (memberUid == _uid && role != 'admin') throw StateError('The current flock administrator cannot be demoted here.');
    final data = {'role': role};
    await _flocks.doc(flockId).collection('members').doc(memberUid).set(data, SetOptions(merge: true));
    await _db.collection('users').doc(memberUid).collection('flock_memberships').doc(flockId).set(data, SetOptions(merge: true));
    if (memberUid == _uid) {
      await _db.collection('users').doc(memberUid).collection('profile').doc('account').set(data, SetOptions(merge: true));
    }
  }

  Future<Map<String, dynamic>?> pendingInvitationForEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final snap = await _db.collectionGroup('invitations').where('email', isEqualTo: normalized).where('status', isEqualTo: 'pending').limit(1).get();
    if (snap.docs.isEmpty) return null;
    final ref = snap.docs.first.reference.parent.parent;
    if (ref == null) return {'email': normalized};
    final flock = await ref.get();
    final data = <String, dynamic>{'email': normalized, 'flockId': ref.id};
    if (flock.exists) data['flockName'] = flock.data()?['name']?.toString() ?? 'Invited flock';
    return data;
  }

  Future<void> completeGoogleProfile({required String role, required String mobileNumber, int? age}) async {
    final user = currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final invitation = await pendingInvitationForEmail(user.email ?? '');
    final effectiveRole = invitation != null ? 'member' : role;
    final data = <String, dynamic>{
      'email': user.email ?? '',
      'displayName': user.displayName ?? user.email ?? 'User',
      'mobileNumber': mobileNumber.trim(),
      'role': effectiveRole,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (age != null) data['age'] = age;
    if (user.photoURL != null && user.photoURL!.isNotEmpty) data['photoURL'] = user.photoURL;
    await _db.collection('users').doc(_uid).collection('profile').doc('account').set(data, SetOptions(merge: true));
    if (effectiveRole == 'member') await _claimPendingInvitations();
  }

  Future<void> removeMember(String flockId, String memberUid) async {
    if (!await isAdmin()) throw StateError('Only an admin can remove members.');
    if (memberUid == _uid) throw StateError('The flock admin cannot remove themselves.');
    await _flocks.doc(flockId).collection('members').doc(memberUid).delete();
    await _db.collection('users').doc(memberUid).collection('flock_memberships').doc(flockId).delete();
  }

  Future<void> _claimPendingInvitations() async {
    final email = currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return;
    final groups = await _db.collectionGroup('invitations').where('email', isEqualTo: email).where('status', isEqualTo: 'pending').get();
    for (final invite in groups.docs) {
      final flockRef = invite.reference.parent.parent;
      if (flockRef == null) continue;
      final flock = await flockRef.get();
      if (!flock.exists) continue;
      final user = currentUser;
      final membership = {'role': 'member', 'email': email, 'displayName': user?.displayName ?? email, 'mobileNumber':'', 'notificationLanguage':'en'};
      await flockRef.collection('members').doc(_uid).set(membership);
      await _memberships.doc(flockRef.id).set(membership);
      await invite.reference.update({'status': 'accepted', 'acceptedByUid': _uid, 'acceptedAt': FieldValue.serverTimestamp()});
    }
  }

  Future<void> setAdminRole(String userId, bool admin) async {
    if (!await isAdmin()) throw StateError('Only an admin can manage roles.');
    await _db.collection('users').doc(userId).collection('profile').doc('account').set({'role': admin ? 'admin' : 'member'}, SetOptions(merge: true));
  }

  Future<void> _ensureGoogleSignInInitialized() {
    _googleSignInInitialization ??= GoogleSignIn.instance.initialize();
    return _googleSignInInitialization!;
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return _auth.signInWithPopup(provider);
    }

    await _ensureGoogleSignInInitialized();
    final googleUser = await GoogleSignIn.instance.authenticate();

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return a valid ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<Map<String, dynamic>> fetchUserProfile() async {
    if (!isSignedIn) throw StateError('You must be signed in.');
    final snap = await _db.collection('users').doc(_uid).collection('profile').doc('account').get();
    return Map<String, dynamic>.from(snap.data() ?? const <String, dynamic>{});
  }

  Future<void> updateUserProfile({
    required String displayName,
    required String email,
    required String mobileNumber,
    int? age,
    String? avatarBase64,
  }) async {
    final user = currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final name = displayName.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final mobile = mobileNumber.trim();
    if (name.length < 2 || name.length > 100) throw ArgumentError('Name must be between 2 and 100 characters.');
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) throw ArgumentError('Enter a valid email address.');
    if (normalizedEmail != (user.email ?? '').trim().toLowerCase()) {
      throw StateError('Email changes must be verified from the account security flow.');
    }
    if (mobile.length < 8 || mobile.length > 20) throw ArgumentError('Mobile number must be between 8 and 20 characters.');
    if (age != null && (age < 1 || age > 120)) throw ArgumentError('Age must be between 1 and 120.');

    await user.updateDisplayName(name);
    final data = <String, dynamic>{
      'email': normalizedEmail,
      'displayName': name,
      'mobileNumber': mobile,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (age != null) data['age'] = age;
    if (avatarBase64 != null) {
      if (avatarBase64.length > 950000) throw ArgumentError('Profile image is too large.');
      data['avatarBase64'] = avatarBase64;
    }
    await _db.collection('users').doc(_uid).collection('profile').doc('account').set(data, SetOptions(merge: true));
  }

  Future<void> createAccount({
    required String email,
    required String password,
    required String displayName,
    required String mobileNumber,
    required String role,
    String? avatarBase64,
  }) async {
    if (role != 'admin' && role != 'member') {
      throw ArgumentError('Invalid account type.');
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Account creation did not return a user.');

    try {
      await user.updateDisplayName(displayName.trim());
      final normalizedEmail = email.trim().toLowerCase();
      final profile = <String, dynamic>{
        'email': normalizedEmail,
        'displayName': displayName.trim(),
        'mobileNumber': mobileNumber.trim(),
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (avatarBase64 != null && avatarBase64.isNotEmpty) {
        profile['avatarBase64'] = avatarBase64;
      }
      await _db.collection('users').doc(user.uid).collection('profile').doc('account').set(profile);

      // A member can immediately join an already-created flock when the
      // owner has invited this email. Uninvited members simply wait for an
      // invitation; no flock access is granted by signup alone.
      if (role == 'member') {
        await _claimPendingInvitations();
      }
    } catch (_) {
      try {
        await user.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await _ensureGoogleSignInInitialized();
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Firebase sign-out remains successful even if the Google session
        // cannot be cleared locally.
      }
    }
  }

  Future<void> _ensureActiveFlock() async {
    if (_activeFlockId != null) return;
    final flocks = await fetchFlocks();
    if (flocks.isNotEmpty) {
      _activeFlockId = flocks.first.id;
      return;
    }
    // Backward-compatible bootstrap: convert the old single-farm configuration
    // into one managed flock and copy the legacy records once.
    final legacyFarm = await _db.collection('users').doc(_uid).collection('settings').doc('farm').get();
    if (!legacyFarm.exists) return;
    final config = FarmConfig.fromMap(legacyFarm.data() ?? const {});
    final id = await createFlock(name: config.breedName.trim().isEmpty ? 'Flock 1' : '${config.breedName} Flock', startDate: config.flockStartDate, startingBirds: config.startingBirds, breedName: config.breedName, accounts: config.accounts, feedItems: config.feedItems);
    _activeFlockId = id;
    await _migrateLegacyRecordsToFlockIfNeeded(id);
  }

  Future<List<PoultryLog>> fetchLogs() async {
    await _ensureActiveFlock();
    final snapshot = await _daily.orderBy('dateKey', descending: true).get();
    final logs = snapshot.docs.map((d) => PoultryLog.fromFirestore(d.data())).toList();
    await _ensureFarmBootstrapConfig(logs);
    return logs;
  }

  Future<List<ExpenseSalesLog>> fetchExpenseRecords() async {
    await _ensureActiveFlock();
    final snapshot = await _expenses.orderBy('dateKey', descending: true).get();
    return snapshot.docs
        .map((d) => ExpenseSalesLog.fromFirestore(d.data(), id: d.id))
        .toList();
  }

  /// Fetches records only from one flock and optionally filters them by
  /// main category, subcategory, supplier and an inclusive date range.
  /// The complete transaction remains in the flock's expense_records collection;
  /// filters are applied here so arbitrary combinations do not require composite
  /// Firestore indexes.
  Future<List<ExpenseSalesLog>> fetchFlockExpenseRecords({
    required String flockId,
    String? mainCategory,
    String? subcategory,
    String? supplierId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!await isAdmin() && !await isFlockMember(flockId)) {
      throw StateError('You do not have access to this flock.');
    }
    Query<Map<String, dynamic>> query =
        _flocks.doc(flockId).collection('expense_records').orderBy('dateKey', descending: true);
    final start = startDate == null ? null : DateTime(startDate.year, startDate.month, startDate.day);
    final endExclusive = endDate == null
        ? null
        : DateTime(endDate.year, endDate.month, endDate.day).add(const Duration(days: 1));
    if (start != null) {
      query = query.where('dateKey', isGreaterThanOrEqualTo: _dateKey(start));
    }
    if (endExclusive != null) {
      query = query.where('dateKey', isLessThan: _dateKey(endExclusive));
    }
    final snapshot = await query.get();
    final main = mainCategory?.trim();
    final sub = subcategory?.trim();
    final supplier = supplierId?.trim();
    return snapshot.docs.map((d) => ExpenseSalesLog.fromFirestore(d.data(), id: d.id)).where((record) {
      if (main != null && main.isNotEmpty && record.mainCategory != main) return false;
      if (sub != null && sub.isNotEmpty && record.category != sub) return false;
      if (supplier != null && supplier.isNotEmpty && record.supplierId != supplier) return false;
      if (start != null && record.date.isBefore(start)) return false;
      if (endExclusive != null && !record.date.isBefore(endExclusive)) return false;
      return true;
    }).toList();
  }

  String _dateKey(DateTime date) => PoultryCalculationService.dateKey(date);

  Future<PoultryLog?> _findPreviousLog(DateTime date) async {
    final key = _dateKey(date);
    final snapshot = await _daily
        .where('dateKey', isLessThan: key)
        .orderBy('dateKey', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return PoultryLog.fromFirestore(snapshot.docs.first.data());
  }

  Future<List<PoultryLog>> _findFutureLogs(String insertedKey) async {
    final snapshot = await _daily
        .where('dateKey', isGreaterThan: insertedKey)
        .orderBy('dateKey')
        .get();
    return snapshot.docs
        .map((d) => PoultryLog.fromFirestore(d.data()))
        .toList();
  }

  Future<void> _ensureFarmBootstrapConfig(List<PoultryLog> logs) async {
    final config = await _farmConfig.get();
    if (config.exists) return;
    if (logs.isEmpty) return;
    final earliest = logs.reduce((a, b) => a.date.isBefore(b.date) ? a : b);
    await _farmConfig.set({
      ...FarmConfig.defaults.toFirestore(),
      'firstLogDateKey': _dateKey(earliest.date),
    });
  }

  Future<List<String>> fetchGlobalFeedItems() async {
    if (!isSignedIn) return FarmConfig.defaultFeedItems;
    final snap = await _db.collection('feed_catalog').doc('global').get();
    if (!snap.exists) return List<String>.from(FarmConfig.defaultFeedItems);
    final raw = snap.data()?['items'];
    if (raw is List) {
      final items = raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet().toList();
      if (items.isNotEmpty) return items;
    }
    return List<String>.from(FarmConfig.defaultFeedItems);
  }

  Future<void> saveGlobalFeedItems(List<String> items) async {
    if (!await isAdmin()) throw StateError('Only an admin can configure feed items.');
    final normalized = items.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    await _db.collection('feed_catalog').doc('global').set({
      'items': normalized.isEmpty ? List<String>.from(FarmConfig.defaultFeedItems) : normalized,
      'updatedByUid': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<String>> fetchGlobalExpenseSubcategories() async {
    if (!isSignedIn) return List<String>.from(ExpenseCategoryConfig.defaultSubcategories);
    final snap = await _db.collection('expense_subcategories').doc('global').get();
    if (!snap.exists) return List<String>.from(ExpenseCategoryConfig.defaultSubcategories);
    final raw = snap.data()?['items'];
    if (raw is List) {
      final items = raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      if (items.isNotEmpty) return items;
    }
    return List<String>.from(ExpenseCategoryConfig.defaultSubcategories);
  }

  Future<void> saveGlobalExpenseSubcategories(List<String> items) async {
    if (!await isAdmin()) throw StateError('Only an admin can configure expense subcategories.');
    final normalized = items
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    await _db.collection('expense_subcategories').doc('global').set({
      'items': normalized.isEmpty ? List<String>.from(ExpenseCategoryConfig.defaultSubcategories) : normalized,
      'updatedByUid': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Supplier>> fetchSuppliers() async {
    if (!isSignedIn) return const [];
    final snap = await _db.collection('suppliers').orderBy('fullName').get();
    return snap.docs.map((d) => Supplier.fromFirestore(d.data(), id: d.id)).toList();
  }

  Future<String> addSupplier(Supplier supplier) async {
    if (!await isAdmin()) throw StateError('Only an admin can manage suppliers.');
    final ref = await _db.collection('suppliers').add({
      ...supplier.toFirestore(),
      'createdByUid': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedByUid': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateSupplier(Supplier supplier) async {
    if (!await isAdmin()) throw StateError('Only an admin can manage suppliers.');
    await _db.collection('suppliers').doc(supplier.id).set({
      ...supplier.toFirestore(),
      'updatedByUid': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteSupplier(String supplierId) async {
    if (!await isAdmin()) throw StateError('Only an admin can manage suppliers.');
    await _db.collection('suppliers').doc(supplierId).delete();
  }

  Future<FarmConfig> fetchFarmConfig() async {
    await _ensureActiveFlock();
    final snap = await _flock.get();
    if (!snap.exists) return FarmConfig.defaults;
    final data = snap.data() ?? const <String, dynamic>{};
    final rawStart = data['startDate'];
    final start = rawStart is Timestamp ? rawStart.toDate() : (DateTime.tryParse(rawStart?.toString() ?? '') ?? FarmConfig.defaultFlockStartDate);
    final accounts = data['accounts'] is List ? (data['accounts'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList() : FarmConfig.defaultAccounts;
    final feedItems = data['feedItems'] is List ? (data['feedItems'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList() : FarmConfig.defaultFeedItems;
    return FarmConfig(flockStartDate: DateTime(start.year, start.month, start.day), startingBirds: (data['startingBirds'] as num?)?.toInt() ?? 0, breedName: data['breedName']?.toString() ?? '', accounts: accounts, feedItems: feedItems);
  }

  Future<void> saveFarmConfig(FarmConfig config) async {
    if (!await isAdmin()) throw StateError('Only an admin can configure a flock.');
    final flock = await fetchFlock(_flockId);
    if (flock == null) throw StateError('Active flock not found.');
    await updateFlock(Flock(id: flock.id, name: flock.name, startDate: config.flockStartDate, endDate: flock.endDate, startingBirds: config.startingBirds, breedName: config.breedName, accounts: config.accounts, feedItems: config.feedItems, createdByUid: flock.createdByUid));
  }

  /// Adds one Daily Log. Bird counts are derived from the opening flock minus
  /// cumulative mortality; they are not stored on individual Daily Logs.
  Future<void> addDailyLog(PoultryLog input) async {
    final normalized = PoultryCalculationService.normalizeDate(input.date);
    final key = _dateKey(normalized);
    if (normalized.isAfter(PoultryCalculationService.normalizeDate(DateTime.now()))) {
      throw StateError('Daily Log date cannot be in the future.');
    }

    final existing = await _daily.doc(key).get();
    if (existing.exists) throw StateError('A Daily Log already exists for $key.');

    final allLogs = await fetchLogs();
    final cumulativeBefore = allLogs
        .where((log) => log.date.isBefore(normalized))
        .fold<int>(0, (sum, log) => sum + log.mortality);
    final farm = await fetchFarmConfig();
    final calculated = PoultryCalculationService.calculate(
      input: input.copyWith(date: normalized),
      cumulativeMortalityBefore: cumulativeBefore,
      openingBirds: farm.startingBirds,
      minimumDate: farm.flockStartDate.add(const Duration(days: 1)),
    );

    final user = currentUser;
    final data = calculated.toFirestore();
    data.addAll({
      'createdByUid': user?.uid,
      'createdByName': user?.displayName ?? user?.email ?? user?.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedByUid': user?.uid,
      'updatedByName': user?.displayName ?? user?.email ?? user?.uid,
    }..removeWhere((key, value) => value == null));
    await _daily.doc(key).set(data);
  }

  /// Updates one Daily Log. Calculated report metrics are derived on read.
  Future<void> updateDailyLog(PoultryLog input) async {
    final normalized = PoultryCalculationService.normalizeDate(input.date);
    final key = _dateKey(normalized);
    if (normalized.isAfter(PoultryCalculationService.normalizeDate(DateTime.now()))) {
      throw StateError('Daily Log date cannot be in the future.');
    }

    final target = await _daily.doc(key).get();
    if (!target.exists) throw StateError('Daily Log not found for $key.');

    final oldData = target.data() ?? const <String, dynamic>{};
    final farm = await fetchFarmConfig();
    final allLogs = await fetchLogs();
    final cumulativeBefore = allLogs
        .where((log) => log.date.isBefore(normalized))
        .fold<int>(0, (sum, log) => sum + log.mortality);
    final calculated = PoultryCalculationService.calculate(
      input: input.copyWith(date: normalized),
      cumulativeMortalityBefore: cumulativeBefore,
      openingBirds: farm.startingBirds,
      minimumDate: farm.flockStartDate.add(const Duration(days: 1)),
    );
    final user = currentUser;
    final data = calculated.toFirestore();
    data.remove('createdAt');
    data.addAll({
      'updatedByUid': user?.uid,
      'updatedByName': user?.displayName ?? user?.email ?? user?.uid,
    }..removeWhere((key, value) => value == null));
    if (oldData['createdByUid'] != null) data['createdByUid'] = oldData['createdByUid'];
    if (oldData['createdByName'] != null) data['createdByName'] = oldData['createdByName'];
    if (oldData['createdAt'] != null) data['createdAt'] = oldData['createdAt'];
    await _daily.doc(key).set(data);
  }

  /// Imports Cashew records using deterministic IDs derived from the source
  /// transaction ID. Existing Cashew records are deliberately updated rather
  /// than skipped so category/account/amount/type changes in the latest
  /// SQLite export repair old imports to the current app rules.
  /// Deletes only records created by the Cashew importer. Manual records
  /// use date-based IDs and are intentionally left untouched.
  Future<int> deleteImportedCashewRecords() async {
    final snapshot = await _expenses.get();
    final imported = snapshot.docs.where((doc) => doc.id.startsWith('cashew_')).toList();
    if (imported.isEmpty) return 0;

    const batchSize = 400;
    for (var start = 0; start < imported.length; start += batchSize) {
      final end = (start + batchSize < imported.length) ? start + batchSize : imported.length;
      final batch = _db.batch();
      for (final doc in imported.sublist(start, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    return imported.length;
  }

  Future<CashewImportResult> importCashewRecords(
    List<Map<String, dynamic>> records, {
    void Function(String message)? onProgress,
  }) async {
    if (records.isEmpty) return const CashewImportResult();

    onProgress?.call('Validating ${records.length} transaction(s)…');
    final parsed = CashewMigrationParser.parseRecords(records);
    var imported = 0;
    var updated = 0;
    var unchanged = 0;

    // Preserve every source account in the active flock configuration so
    // imported Cashew transactions remain selectable/editable after import.
    final importedAccounts = parsed
        .map((item) => item['account']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (importedAccounts.isNotEmpty) {
      await _flock.set({
        'accounts': FieldValue.arrayUnion(importedAccounts),
      }, SetOptions(merge: true));
    }

    // Use one read of the user's expense collection. This is intentionally
    // simpler and more reliable on Web/Safari than a series of whereIn calls.
    onProgress?.call('Checking existing transactions…');
    final existingSnapshot = await _expenses.get().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw StateError(
        'Timed out reading Firestore expense records after 30 seconds. ' 
        'Check the Safari console/network connection.',
      ),
    );
    final existing = <String, Map<String, dynamic>>{
      for (final doc in existingSnapshot.docs) doc.id: doc.data(),
    };

    // Small commits make Web imports observable and prevent one large request
    // from looking like an endless import.
    const writeBatchSize = 20;
    final totalBatches = (parsed.length + writeBatchSize - 1) ~/ writeBatchSize;

    for (var start = 0; start < parsed.length; start += writeBatchSize) {
      final end = (start + writeBatchSize < parsed.length)
          ? start + writeBatchSize
          : parsed.length;
      final chunk = parsed.sublist(start, end);
      final batchNumber = (start ~/ writeBatchSize) + 1;
      onProgress?.call('Writing batch $batchNumber of $totalBatches ($start–$end)…');

      final batch = _db.batch();
      var writes = 0;

      for (final item in chunk) {
        final transactionId = item['transactionId'] as String;
        final date = DateTime.tryParse(item['date'] as String);
        if (date == null) {
          throw StateError('Invalid date for transaction $transactionId.');
        }

        final source = item['source']?.toString() ?? '';
        final id = source == 'poultry_inventory_export'
            ? transactionId
            : (transactionId.startsWith('cashew_') ? transactionId : 'cashew_$transactionId');
        if (id.trim().isEmpty) {
          throw StateError('Cashew/app export contains a transaction without an ID.');
        }

        final mainCategory = item['mainCategory'] as String;
        final category = item['category'] as String;
        if (!ExpenseCategoryConfig.isValidMainCategory(mainCategory) ||
            !ExpenseCategoryConfig.isValidSubcategory(mainCategory, category)) {
          throw StateError(
            'Cashew transaction $transactionId has unsupported mapping: $mainCategory / $category.',
          );
        }

        final record = ExpenseSalesLog(
          id: id,
          date: date,
          mainCategory: mainCategory,
          category: category,
          originalCategory: item['originalCategory'] as String,
          account: item['account'] as String,
          description: (item['description'] as String).length > 500
              ? (item['description'] as String).substring(0, 500)
              : item['description'] as String,
          supplierId: item['supplierId']?.toString(),
          supplierName: item['supplierName']?.toString(),
          amount: item['amount'] as double,
          unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? 0.0,
          freightCharge: (item['freightCharge'] as num?)?.toDouble() ?? 0.0,
          pricingCalculated: item['pricingCalculated'] == true,
          medicalItems: ((item['medicalItems'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          feedItems: ((item['feedItems'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          unit: item['unit'] as String,
          quantity: item['quantity'] as double,
          transactionType: item['transactionType'] as String,
        );

        final oldData = existing[id];
        final ref = _expenses.doc(id);

        if (oldData == null) {
          final data = record.toFirestore(includeCreatedAt: false);
          data['createdAt'] = Timestamp.fromDate(record.date);
          final user = currentUser;
          data['createdByUid'] = user?.uid;
          data['createdByName'] = user?.displayName ?? user?.email ?? user?.uid;
          data['updatedByUid'] = user?.uid;
          data['updatedByName'] = user?.displayName ?? user?.email ?? user?.uid;
          data.removeWhere((key, value) => value == null);
          batch.set(ref, data);
          imported++;
          writes++;
          continue;
        }

        final existingRecord = ExpenseSalesLog.fromFirestore(oldData, id: id);
        final changed = existingRecord.date != record.date ||
            existingRecord.mainCategory != record.mainCategory ||
            existingRecord.category != record.category ||
            existingRecord.originalCategory != record.originalCategory ||
            existingRecord.account != record.account ||
            existingRecord.description != record.description ||
            existingRecord.supplierId != record.supplierId ||
            existingRecord.supplierName != record.supplierName ||
            existingRecord.amount != record.amount ||
            existingRecord.unitPrice != record.unitPrice ||
            existingRecord.freightCharge != record.freightCharge ||
            existingRecord.pricingCalculated != record.pricingCalculated ||
            existingRecord.medicalItems.toString() != record.medicalItems.toString() ||
            existingRecord.feedItems.toString() != record.feedItems.toString() ||
            existingRecord.unit != record.unit ||
            existingRecord.quantity != record.quantity ||
            existingRecord.transactionType != record.transactionType;

        final user = currentUser;
        final creatorUid = user?.uid;
        final creatorName = user?.displayName ?? user?.email ?? user?.uid;
        final auditNeedsBackfill = oldData['createdByUid'] != creatorUid ||
            oldData['createdByName'] != creatorName;

        if (!changed && !auditNeedsBackfill) {
          unchanged++;
          continue;
        }

        final data = record.toFirestore(includeCreatedAt: false);
        final createdAt = oldData['createdAt'];
        data['createdAt'] = createdAt is Timestamp ? createdAt : Timestamp.fromDate(record.date);
        data['createdByUid'] = creatorUid;
        data['createdByName'] = creatorName;
        data['updatedByUid'] = user?.uid;
        data['updatedByName'] = user?.displayName ?? user?.email ?? user?.uid;
        data.removeWhere((key, value) => value == null);
        batch.set(ref, data);
        updated++;
        writes++;
      }

      if (writes > 0) {
        try {
          await batch.commit().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw StateError(
              'Timed out committing import batch $batchNumber/$totalBatches after 30 seconds. ' 
              'Open Safari Web Inspector → Console for the underlying Firestore/network error.',
            ),
          );
        } on FirebaseException catch (e) {
          // Older versions of the deployed Firestore rules do not know about
          // the newer pricing fields (unitPrice/freightCharge/pricingCalculated)
          // or optional Medical line items. If such rules are still deployed,
          // retry this atomic batch with the legacy expense shape. Once the
          // latest rules are deployed, the normal payload is used.
          if (e.code != 'permission-denied') {
            throw StateError('Firestore rejected import batch $batchNumber/$totalBatches: ${e.message ?? e.code}');
          }

          onProgress?.call(
            'Current Firestore rules rejected the new fields; retrying batch $batchNumber/$totalBatches with legacy-compatible expense fields…',
          );
          final legacyBatch = _db.batch();
          for (final item in chunk) {
            final transactionId = item['transactionId'] as String;
            final date = DateTime.tryParse(item['date'] as String);
            if (date == null) continue;
            final source = item['source']?.toString() ?? '';
            final id = source == 'poultry_inventory_export'
                ? transactionId
                : (transactionId.startsWith('cashew_') ? transactionId : 'cashew_$transactionId');
            final oldData = existing[id];
            final record = ExpenseSalesLog(
              id: id,
              date: date,
              mainCategory: item['mainCategory'] as String,
              category: item['category'] as String,
              originalCategory: item['originalCategory'] as String,
              account: item['account'] as String,
              description: (item['description'] as String).length > 500
                  ? (item['description'] as String).substring(0, 500)
                  : item['description'] as String,
              amount: item['amount'] as double,
              unit: item['unit'] as String,
              quantity: item['quantity'] as double,
              transactionType: item['transactionType'] as String,
            );
            final data = <String, dynamic>{
              'date': Timestamp.fromDate(record.date),
              'dateKey': DateFormat('yyyy-MM-dd').format(record.date),
              'mainCategory': record.mainCategory.trim().isEmpty ? 'Layer Bird' : record.mainCategory.trim(),
              'category': record.category.trim(),
              'originalCategory': record.originalCategory.trim().isEmpty ? record.category.trim() : record.originalCategory.trim(),
              'account': record.account.trim().isEmpty ? 'Amzad Khan' : record.account.trim(),
              'description': record.description,
              'amount': record.amount,
              'unit': record.unit,
              'quantity': record.quantity,
              'transactionType': record.transactionType,
              'createdAt': oldData?['createdAt'] is Timestamp
                  ? oldData!['createdAt']
                  : Timestamp.fromDate(record.date),
            };
            legacyBatch.set(_expenses.doc(id), data);
          }

          try {
            await legacyBatch.commit().timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw StateError(
                'Timed out committing legacy import batch $batchNumber/$totalBatches after 30 seconds.',
              ),
            );
          } on FirebaseException catch (legacyError) {
            throw StateError(
              'Firestore rejected import batch $batchNumber/$totalBatches: permission-denied. ' 
              'The deployed Firestore rules are incompatible with this app. ' 
              'Deploy the latest firestore.rules, then retry the import. (${legacyError.message ?? legacyError.code})',
            );
          }
        }
      }
    }

    onProgress?.call('Import finished.');
    return CashewImportResult(imported: imported, updated: updated, unchanged: unchanged);
  }

  Future<void> updateExpenseRecord(ExpenseSalesLog record) async {
    if (record.id == null || record.id!.trim().isEmpty) {
      throw StateError('Expense record ID is missing.');
    }
    if (record.amount < 0 || record.quantity < 0) {
      throw StateError('Amount and quantity cannot be negative.');
    }
    if (record.mainCategory.trim().isEmpty || record.category.trim().isEmpty) {
      throw StateError('Main category and category are required.');
    }
    final ref = _expenses.doc(record.id);
    final existing = await ref.get();
    if (!existing.exists) throw StateError('Expense record no longer exists.');
    final user = currentUser;
    final data = record.toFirestore(includeCreatedAt: false);
    final oldData = existing.data() ?? const <String, dynamic>{};
    if (oldData['createdAt'] != null) data['createdAt'] = oldData['createdAt'];
    else data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedByUid'] = user?.uid;
    data['updatedByName'] = user?.displayName ?? user?.email ?? user?.uid;
    if (oldData['createdByUid'] != null) data['createdByUid'] = oldData['createdByUid'];
    if (oldData['createdByName'] != null) data['createdByName'] = oldData['createdByName'];
    data.removeWhere((key, value) => value == null);
    await ref.set(data);
  }

  Future<void> addExpenseRecord(ExpenseSalesLog record) async {
    if (record.amount < 0 || record.quantity < 0) {
      throw StateError('Amount and quantity cannot be negative.');
    }
    if (record.category.trim().isEmpty) {
      throw StateError('Expense/Sales category is required.');
    }
    if (record.mainCategory.trim().isEmpty) {
      throw StateError('Main category is required.');
    }

    // Randomized microsecond suffix avoids collisions when multiple records
    // are created on the same day. The date is still stored separately for
    // querying and reporting.
    final key = '${_dateKey(record.date)}_${DateTime.now().microsecondsSinceEpoch}';
    final user = currentUser;
    final data = record.toFirestore();
    data.addAll({
      'createdByUid': user?.uid,
      'createdByName': user?.displayName ?? user?.email ?? user?.uid,
      'updatedByUid': user?.uid,
      'updatedByName': user?.displayName ?? user?.email ?? user?.uid,
    }..removeWhere((key, value) => value == null));
    await _expenses.doc(key).set(data);
  }
}
