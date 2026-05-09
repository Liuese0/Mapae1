import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../constants/supabase_constants.dart';
import '../../features/shared/models/app_user.dart';
import '../../features/shared/models/business_card.dart';
import '../../features/shared/models/collected_card.dart';
import '../../features/shared/models/category.dart';
import '../../features/shared/models/team.dart';
import '../../features/shared/models/context_tag.dart';
import '../../features/shared/models/team_invitation.dart';
import '../../features/shared/models/crm_contact.dart';
import 'app_exception.dart' as app;
import 'caller_id_service.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ──────────────── Auth ────────────────

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
      emailRedirectTo: 'com.namecard.app://login-callback',
    );
    return response;
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signInWithGoogle() async {
    final webClientId = AppConstants.googleWebClientId;
    final iosClientId = AppConstants.googleIosClientId;

    final googleSignIn = GoogleSignIn(
      clientId: iosClientId,
      serverClientId: webClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw app.AuthException.googleCancelled();
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw app.AuthException.googleTokenMissing();
    }

    return await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<bool> signInWithKakao() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: 'com.namecard.app://login-callback',
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw app.AuthException.notLoggedIn();

    // Call DB function that deletes all user data + auth.users row
    await _client.rpc('delete_user_account');

    await _client.auth.signOut();
  }

  Future<void> updateUserName(String name) async {
    final user = currentUser;
    if (user == null) throw app.AuthException.notLoggedIn();

    await _client
        .from(SupabaseConstants.usersTable)
        .update({'name': name})
        .eq('id', user.id);
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// OAuth 사용자가 비밀번호를 설정할 수 있도록 함
  Future<void> setPassword(String password) async {
    await _client.auth.updateUser(UserAttributes(
      password: password,
      data: {'password_set': true},
    ));
  }

  /// OAuth 사용자가 이미 비밀번호를 설정했는지 확인
  bool get hasPasswordSet {
    final meta = _client.auth.currentUser?.userMetadata;
    if (meta == null) return false;
    return meta['password_set'] == true;
  }

  /// 로그인 후 프로필이 없으면 자동 생성
  Future<AppUser> ensureUserProfile() async {
    final user = currentUser;
    if (user == null) throw app.AuthException.notLoggedIn();

    final existing = await getUserProfile(user.id);
    if (existing != null) return existing;

    final name = user.userMetadata?['name'] as String? ??
        user.userMetadata?['full_name'] as String? ??
        '';
    final email = user.email ?? '';

    await _client.from(SupabaseConstants.usersTable).upsert({
      'id': user.id,
      'name': name,
      'email': email,
      'locale': 'ko',
      'is_dark_mode': false,
      'created_at': DateTime.now().toIso8601String(),
    });

    return (await getUserProfile(user.id))!;
  }

  // ──────────────── User Profile ────────────────

  Future<AppUser?> getUserProfile(String userId) async {
    final data = await _client
        .from(SupabaseConstants.usersTable)
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return AppUser.fromJson(data);
  }

  Future<void> updateUserProfile(AppUser user) async {
    await _client
        .from(SupabaseConstants.usersTable)
        .update(user.toJson())
        .eq('id', user.id);
  }

  // ──────────────── My Business Cards ────────────────

  Future<List<BusinessCard>> getMyCards(String userId) async {
    final data = await _client
        .from(SupabaseConstants.myCardsTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return data.map((json) => BusinessCard.fromJson(json)).toList();
  }

  Future<BusinessCard> createMyCard(BusinessCard card) async {
    final data = await _client
        .from(SupabaseConstants.myCardsTable)
        .insert(card.toJson())
        .select()
        .single();
    return BusinessCard.fromJson(data);
  }

  Future<BusinessCard> updateMyCard(BusinessCard card) async {
    final data = await _client
        .from(SupabaseConstants.myCardsTable)
        .update(card.toJson())
        .eq('id', card.id)
        .select()
        .single();
    return BusinessCard.fromJson(data);
  }

  Future<void> deleteMyCard(String cardId) async {
    await _client
        .from(SupabaseConstants.myCardsTable)
        .delete()
        .eq('id', cardId);
  }

  // ──────────────── Collected Cards ────────────────

  Future<List<CollectedCard>> getCollectedCards(
      String userId, {
        String? categoryId,
        String sortBy = 'created_at',
        bool ascending = false,
        int offset = 0,
        int limit = 20,
        bool? isFavorite,
      }) async {
    var query = _client
        .from(SupabaseConstants.collectedCardsTable)
        .select('*, categories(name)')
        .eq('user_id', userId);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    if (isFavorite == true) {
      query = query.eq('is_favorite', true);
    }

    final data = await query
        .order('is_favorite', ascending: false)
        .order(sortBy, ascending: ascending)
        .range(offset, offset + limit - 1);
    return data.map((json) => CollectedCard.fromJson(json)).toList();
  }

  Future<CollectedCard> addCollectedCard(CollectedCard card) async {
    final data = await _client
        .from(SupabaseConstants.collectedCardsTable)
        .insert(card.toJson())
        .select()
        .single();
    final result = CollectedCard.fromJson(data);
    _refreshCallerIdCache();
    return result;
  }

  Future<CollectedCard> updateCollectedCard(CollectedCard card) async {
    final data = await _client
        .from(SupabaseConstants.collectedCardsTable)
        .update(card.toJson())
        .eq('id', card.id)
        .select()
        .single();
    final result = CollectedCard.fromJson(data);
    _refreshCallerIdCache();
    return result;
  }

  Future<void> deleteCollectedCard(String cardId) async {
    await _client
        .from(SupabaseConstants.collectedCardsTable)
        .delete()
        .eq('id', cardId);
    _refreshCallerIdCache();
  }

  Future<void> toggleFavorite(String cardId, bool isFavorite) async {
    await _client
        .from(SupabaseConstants.collectedCardsTable)
        .update({'is_favorite': isFavorite})
        .eq('id', cardId);
    // 즐겨찾기 토글은 인덱스에 영향이 없지만 imageUrl/이름이 동기화되도록 한 번 더.
    _refreshCallerIdCache();
  }

  /// 명함 변경 후 Caller ID 인덱스/캐시를 백그라운드로 새로고침합니다.
  /// 호출자의 응답 시간을 늘리지 않도록 await 하지 않습니다.
  void _refreshCallerIdCache() {
    final user = currentUser;
    if (user == null) return;
    Future(() async {
      try {
        final caller = CallerIdService();
        final enabled = await caller.isEnabled;
        if (!enabled) return;
        final cards = await getCollectedCards(user.id, limit: 10000);
        await caller.syncCardsFromList(cards);
      } catch (_) {
        // 동기화 실패는 사용자 흐름을 막지 않습니다.
      }
    });
  }

  Future<int> getCollectedCardCount(String userId) async {
    final result = await _client
        .from(SupabaseConstants.collectedCardsTable)
        .select()
        .eq('user_id', userId)
        .count(CountOption.exact);
    return result.count;
  }

  /// 이메일 또는 전화번호로 중복 명함 조회
  Future<List<CollectedCard>> findDuplicates(String userId, {String? email, String? phone, String? mobile}) async {
    if (email == null && phone == null && mobile == null) return [];

    var query = _client
        .from(SupabaseConstants.collectedCardsTable)
        .select()
        .eq('user_id', userId);

    // OR 조건으로 이메일/전화번호 매칭
    final orConditions = <String>[];
    if (email != null && email.isNotEmpty) orConditions.add('email.eq.$email');
    if (phone != null && phone.isNotEmpty) orConditions.add('phone.eq.$phone');
    if (mobile != null && mobile.isNotEmpty) orConditions.add('mobile.eq.$mobile');

    if (orConditions.isEmpty) return [];

    final data = await query.or(orConditions.join(','));
    return data.map((json) => CollectedCard.fromJson(json)).toList();
  }

  // ──────────────── Categories ────────────────

  Future<List<CardCategory>> getCategories(String userId) async {
    final data = await _client
        .from(SupabaseConstants.categoriesTable)
        .select()
        .eq('user_id', userId)
        .isFilter('team_id', null)
        .order('sort_order');
    return data.map((json) => CardCategory.fromJson(json)).toList();
  }

  Future<CardCategory> createCategory(CardCategory category) async {
    final data = await _client
        .from(SupabaseConstants.categoriesTable)
        .insert(category.toJson())
        .select()
        .single();
    return CardCategory.fromJson(data);
  }

  Future<void> deleteCategory(String categoryId) async {
    await _client
        .from(SupabaseConstants.categoriesTable)
        .delete()
        .eq('id', categoryId);
  }

  // ──────────────── Team Categories ────────────────

  Future<List<CardCategory>> getTeamCategories(String teamId) async {
    final data = await _client
        .from(SupabaseConstants.categoriesTable)
        .select()
        .eq('team_id', teamId)
        .order('sort_order');
    return data.map((json) => CardCategory.fromJson(json)).toList();
  }

  Future<CardCategory> createTeamCategory(CardCategory category) async {
    final data = await _client
        .from(SupabaseConstants.categoriesTable)
        .insert(category.toJson())
        .select()
        .single();
    return CardCategory.fromJson(data);
  }

  Future<void> updateSharedCardCategory(String sharedCardId, String? categoryId) async {
    await _client
        .from(SupabaseConstants.teamSharedCardsTable)
        .update({'category_id': categoryId})
        .eq('id', sharedCardId);
  }

  // ──────────────── Teams ────────────────

  Future<List<Team>> getUserTeams(String userId) async {
    final memberData = await _client
        .from(SupabaseConstants.teamMembersTable)
        .select('team_id')
        .eq('user_id', userId);

    final teamIds =
    memberData.map((m) => m['team_id'] as String).toList();

    if (teamIds.isEmpty) return [];

    final data = await _client
        .from(SupabaseConstants.teamsTable)
        .select()
        .inFilter('id', teamIds);
    return data.map((json) => Team.fromJson(json)).toList();
  }

  Future<Team> createTeam(Team team, String userId) async {
    final data = await _client
        .from(SupabaseConstants.teamsTable)
        .insert(team.toJson())
        .select()
        .single();

    // Add creator as owner
    final profile = await getUserProfile(userId);
    await _client.from(SupabaseConstants.teamMembersTable).insert({
      'team_id': data['id'],
      'user_id': userId,
      'role': TeamRole.owner.name,
      'user_name': profile?.name ?? '이름 없음',
      'joined_at': DateTime.now().toIso8601String(),
    });

    return Team.fromJson(data);
  }

  Future<List<TeamMember>> getTeamMembers(String teamId) async {
    final data = await _client
        .from(SupabaseConstants.teamMembersTable)
        .select()
        .eq('team_id', teamId);
    return data.map((json) => TeamMember.fromJson(json)).toList();
  }

  Future<void> addTeamMember(String teamId, String userId, {TeamRole role = TeamRole.observer}) async {
    final profile = await getUserProfile(userId);
    await _client.from(SupabaseConstants.teamMembersTable).insert({
      'team_id': teamId,
      'user_id': userId,
      'role': role.name,
      'user_name': profile?.name ?? '이름 없음',
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  /// Owner가 멤버의 역할을 변경 (observer <-> member)
  Future<void> updateMemberRole(String teamId, String memberId, TeamRole newRole) async {
    await _client
        .from(SupabaseConstants.teamMembersTable)
        .update({'role': newRole.name})
        .eq('id', memberId);
  }

  /// Owner 권한 양도
  Future<void> transferOwnership(String teamId, String currentOwnerId, String newOwnerId) async {
    await _client.rpc('transfer_team_ownership', params: {
      'p_team_id': teamId,
      'p_current_owner_id': currentOwnerId,
      'p_new_owner_id': newOwnerId,
    });
  }

  Future<void> deleteTeam(String teamId) async {
    await _client
        .from(SupabaseConstants.teamsTable)
        .delete()
        .eq('id', teamId);
  }

  Future<void> leaveTeam(String teamId, String userId) async {
    await _client
        .from(SupabaseConstants.teamMembersTable)
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId);
  }

  /// 단일 팀 조회 (share_code, share_code_enabled 포함)
  Future<Team?> getTeam(String teamId) async {
    final data = await _client
        .from(SupabaseConstants.teamsTable)
        .select()
        .eq('id', teamId)
        .maybeSingle();
    if (data == null) return null;
    return Team.fromJson(data);
  }

  /// 팀 공유코드 생성 (오너 전용) — RPC 호출
  Future<String> generateTeamShareCode(String teamId) async {
    final result = await _client.rpc(
      'generate_team_share_code',
      params: {'p_team_id': teamId},
    );
    return result as String;
  }

  /// 팀 공유코드 활성/비활성 토글 (오너 전용) — RPC 호출
  Future<void> toggleTeamShareCode(String teamId, {required bool enabled}) async {
    await _client.rpc(
      'toggle_team_share_code',
      params: {'p_team_id': teamId, 'p_enabled': enabled},
    );
  }

  /// 공유코드로 팀 참가 — observer로 합류, 결과 Map 반환
  Future<Map<String, dynamic>> joinTeamByShareCode(String shareCode) async {
    final result = await _client.rpc(
      'join_team_by_share_code',
      params: {'p_share_code': shareCode.trim().toUpperCase()},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// 명함을 팀에 공유 (스냅샷 저장 — 원본 삭제 시에도 유지)
  Future<void> shareCardToTeam(String cardId, String teamId, {String? categoryId}) async {
    final userId = currentUser?.id;
    if (userId == null) throw app.AuthException.notLoggedIn();

    await _client.rpc('share_card_to_team', params: {
      'p_card_id': cardId,
      'p_team_id': teamId,
      'p_user_id': userId,
      'p_category_id': categoryId,
    });
  }

  /// 특정 명함이 공유된 팀 목록 조회
  Future<List<Map<String, dynamic>>> getTeamsWhereCardIsShared(String cardId) async {
    final data = await _client
        .from(SupabaseConstants.teamSharedCardsTable)
        .select('id, team_id')
        .eq('card_id', cardId);
    return data;
  }

  Future<void> unshareCardFromTeam(String sharedCardId) async {
    await _client.rpc('unshare_card_from_team', params: {
      'p_shared_card_id': sharedCardId,
    });
  }

  /// 공유 명함 정보 수정 + 연결된 CRM 연락처 동기화
  Future<void> updateSharedCard(String sharedCardId, Map<String, dynamic> fields) async {
    const allowedFields = {'name', 'company', 'position', 'department', 'email', 'phone', 'mobile', 'fax', 'address', 'website', 'sns_url', 'memo'};
    final sanitized = Map.fromEntries(
      fields.entries.where((e) => allowedFields.contains(e.key)),
    );
    if (sanitized.isEmpty) return;

    // 공유 명함 업데이트
    await _client
        .from(SupabaseConstants.teamSharedCardsTable)
        .update(sanitized)
        .eq('id', sharedCardId);

    // 연결된 CRM 연락처도 동기화
    final syncFields = <String, dynamic>{};
    const syncKeys = ['name', 'company', 'position', 'department', 'email', 'phone', 'mobile'];
    for (final key in syncKeys) {
      if (sanitized.containsKey(key)) {
        syncFields[key] = sanitized[key];
      }
    }
    if (syncFields.isNotEmpty) {
      syncFields['updated_at'] = DateTime.now().toIso8601String();
      await _client
          .from(SupabaseConstants.crmContactsTable)
          .update(syncFields)
          .eq('shared_card_id', sharedCardId);
    }
  }

  /// CRM 연락처 수정 시 연결된 공유 명함도 동기화
  Future<void> syncCrmToSharedCard(CrmContact contact) async {
    if (contact.sharedCardId == null) return;

    final syncFields = <String, dynamic>{
      'name': contact.name,
      'company': contact.company,
      'position': contact.position,
      'department': contact.department,
      'email': contact.email,
      'phone': contact.phone,
      'mobile': contact.mobile,
    };

    await _client
        .from(SupabaseConstants.teamSharedCardsTable)
        .update(syncFields)
        .eq('id', contact.sharedCardId!);
  }

  /// 팀 공유 명함 목록 (스냅샷 데이터에서 직접 읽기)
  Future<List<Map<String, dynamic>>> getTeamSharedCards(String teamId, {int offset = 0, int limit = 20}) async {
    final data = await _client
        .from(SupabaseConstants.teamSharedCardsTable)
        .select()
        .eq('team_id', teamId)
        .order('shared_at', ascending: false)
        .range(offset, offset + limit - 1);
    return data;
  }

  /// 공유된 명함을 내 지갑으로 복사
  Future<CollectedCard> copySharedCardToWallet(Map<String, dynamic> sharedCard) async {
    final userId = currentUser?.id;
    if (userId == null) throw app.AuthException.notLoggedIn();

    final newCard = CollectedCard(
      id: '',
      userId: userId,
      name: sharedCard['name'] as String?,
      company: sharedCard['company'] as String?,
      position: sharedCard['position'] as String?,
      department: sharedCard['department'] as String?,
      email: sharedCard['email'] as String?,
      phone: sharedCard['phone'] as String?,
      mobile: sharedCard['mobile'] as String?,
      fax: sharedCard['fax'] as String?,
      address: sharedCard['address'] as String?,
      website: sharedCard['website'] as String?,
      snsUrl: sharedCard['sns_url'] as String?,
      memo: sharedCard['memo'] as String?,
      imageUrl: sharedCard['image_url'] as String?,
      sourceCardId: sharedCard['card_id'] as String?,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return addCollectedCard(newCard);
  }

  // ──────────────── Team Invitations ────────────────

  /// 이메일로 유저 검색 (RPC 사용 - users 테이블 RLS 우회)
  Future<List<AppUser>> searchUsersByEmail(String email) async {
    final data = await _client.rpc(
      'search_users_by_email',
      params: {'search_query': email},
    );
    return (data as List)
        .map((json) => AppUser.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 팀 초대 보내기
  Future<TeamInvitation> sendTeamInvitation({
    required String teamId,
    required String inviteeId,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw app.AuthException.notLoggedIn();

    final data = await _client
        .from(SupabaseConstants.teamInvitationsTable)
        .insert({
      'team_id': teamId,
      'inviter_id': userId,
      'invitee_id': inviteeId,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    })
        .select('*, teams:team_id(name), inviter:inviter_id(name), invitee:invitee_id(name, email)')
        .single();
    return TeamInvitation.fromJson(data);
  }

  /// 내가 받은 대기 중인 초대 목록
  Future<List<TeamInvitation>> getReceivedInvitations() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from(SupabaseConstants.teamInvitationsTable)
        .select('*, teams:team_id(name), inviter:inviter_id(name)')
        .eq('invitee_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return data.map((json) => TeamInvitation.fromJson(json)).toList();
  }

  /// 대기 중인 초대 수
  Future<int> getPendingInvitationCount() async {
    final userId = currentUser?.id;
    if (userId == null) return 0;

    final result = await _client
        .from(SupabaseConstants.teamInvitationsTable)
        .select()
        .eq('invitee_id', userId)
        .eq('status', 'pending')
        .count(CountOption.exact);
    return result.count;
  }

  /// 초대 수락
  Future<void> acceptInvitation(TeamInvitation invitation) async {
    // SECURITY DEFINER RPC로 초대 검증 → status 업데이트 → team_members 삽입을 원자적으로 처리
    // (team_members INSERT 정책이 오너만 허용하므로 RPC로 우회)
    await _client.rpc('accept_team_invitation', params: {
      'invitation_id': invitation.id,
    });
  }

  /// 초대 거절
  Future<void> declineInvitation(String invitationId) async {
    await _client
        .from(SupabaseConstants.teamInvitationsTable)
        .update({
      'status': 'declined',
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', invitationId);
  }

  /// 팀의 대기 중인 초대 목록 (초대한 사람이 확인)
  Future<List<TeamInvitation>> getTeamPendingInvitations(String teamId) async {
    final data = await _client
        .from(SupabaseConstants.teamInvitationsTable)
        .select('*, invitee:invitee_id(name, email)')
        .eq('team_id', teamId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return data.map((json) => TeamInvitation.fromJson(json)).toList();
  }

  /// 초대 취소 (삭제)
  Future<void> cancelInvitation(String invitationId) async {
    await _client
        .from(SupabaseConstants.teamInvitationsTable)
        .delete()
        .eq('id', invitationId);
  }

  // ──────────────── Context Tags ────────────────

  Future<List<TagTemplate>> getTagTemplates(String userId) async {
    final data = await _client
        .from(SupabaseConstants.tagTemplatesTable)
        .select()
        .eq('user_id', userId);
    return data.map((json) => TagTemplate.fromJson(json)).toList();
  }

  Future<TagTemplate> createTagTemplate(TagTemplate template) async {
    final data = await _client
        .from(SupabaseConstants.tagTemplatesTable)
        .insert(template.toJson())
        .select()
        .single();
    return TagTemplate.fromJson(data);
  }

  Future<void> deleteTagTemplate(String templateId) async {
    await _client
        .from(SupabaseConstants.tagTemplatesTable)
        .delete()
        .eq('id', templateId);
  }

  Future<List<ContextTag>> getCardTags(String cardId) async {
    final data = await _client
        .from(SupabaseConstants.contextTagsTable)
        .select()
        .eq('card_id', cardId);
    return data.map((json) => ContextTag.fromJson(json)).toList();
  }

  Future<ContextTag> addContextTag(ContextTag tag) async {
    final data = await _client
        .from(SupabaseConstants.contextTagsTable)
        .insert(tag.toJson())
        .select()
        .single();
    return ContextTag.fromJson(data);
  }

  Future<void> updateContextTag(ContextTag tag) async {
    await _client
        .from(SupabaseConstants.contextTagsTable)
        .update(tag.toJson())
        .eq('id', tag.id);
  }

  Future<void> deleteContextTag(String tagId) async {
    await _client
        .from(SupabaseConstants.contextTagsTable)
        .delete()
        .eq('id', tagId);
  }

  // ──────────────── CRM ────────────────

  /// CRM 연락처 목록 조회
  Future<List<CrmContact>> getCrmContacts(String teamId, {CrmStatus? status}) async {
    var query = _client
        .from(SupabaseConstants.crmContactsTable)
        .select()
        .eq('team_id', teamId);

    if (status != null) {
      query = query.eq('status', status.name);
    }

    final data = await query.order('updated_at', ascending: false);
    return data.map((json) => CrmContact.fromJson(json)).toList();
  }

  /// CRM 연락처 생성
  Future<CrmContact> createCrmContact(CrmContact contact) async {
    final data = await _client
        .from(SupabaseConstants.crmContactsTable)
        .insert(contact.toJson())
        .select()
        .single();
    return CrmContact.fromJson(data);
  }

  /// CRM 연락처 수정
  Future<CrmContact> updateCrmContact(CrmContact contact) async {
    final data = await _client
        .from(SupabaseConstants.crmContactsTable)
        .update({
      ...contact.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', contact.id)
        .select()
        .single();
    return CrmContact.fromJson(data);
  }

  /// CRM 연락처 상태 변경
  Future<void> updateCrmContactStatus(String contactId, CrmStatus status) async {
    await _client
        .from(SupabaseConstants.crmContactsTable)
        .update({
      'status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', contactId);
  }

  /// CRM 팔로업 제거
  Future<void> clearCrmContactFollowUp(String contactId) async {
    await _client
        .from(SupabaseConstants.crmContactsTable)
        .update({
      'follow_up_date': null,
      'follow_up_note': null,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', contactId);
  }

  /// CRM 연락처 삭제
  Future<void> deleteCrmContact(String contactId) async {
    await _client
        .from(SupabaseConstants.crmContactsTable)
        .delete()
        .eq('id', contactId);
  }

  /// 공유 명함에서 CRM 연락처로 가져오기
  Future<CrmContact> importSharedCardToCrm(Map<String, dynamic> sharedCard, String teamId) async {
    final userId = currentUser?.id;
    if (userId == null) throw app.AuthException.notLoggedIn();

    final contact = CrmContact(
      id: '',
      teamId: teamId,
      sharedCardId: sharedCard['id'] as String?,
      createdBy: userId,
      name: sharedCard['name'] as String?,
      company: sharedCard['company'] as String?,
      position: sharedCard['position'] as String?,
      department: sharedCard['department'] as String?,
      email: sharedCard['email'] as String?,
      phone: sharedCard['phone'] as String?,
      mobile: sharedCard['mobile'] as String?,
      status: CrmStatus.lead,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return createCrmContact(contact);
  }

  /// CRM 노트 목록 조회
  Future<List<CrmNote>> getCrmNotes(String contactId) async {
    final data = await _client
        .from(SupabaseConstants.crmNotesTable)
        .select()
        .eq('contact_id', contactId)
        .order('created_at', ascending: false);
    return data.map((json) => CrmNote.fromJson(json)).toList();
  }

  /// CRM 노트 추가
  Future<CrmNote> addCrmNote(CrmNote note) async {
    final data = await _client
        .from(SupabaseConstants.crmNotesTable)
        .insert(note.toJson())
        .select()
        .single();
    return CrmNote.fromJson(data);
  }

  /// CRM 노트 삭제
  Future<void> deleteCrmNote(String noteId) async {
    await _client
        .from(SupabaseConstants.crmNotesTable)
        .delete()
        .eq('id', noteId);
  }

  /// CRM 파이프라인 통계
  Future<Map<CrmStatus, int>> getCrmPipelineStats(String teamId) async {
    final data = await _client
        .from(SupabaseConstants.crmContactsTable)
        .select('status')
        .eq('team_id', teamId);

    final stats = <CrmStatus, int>{};
    for (final status in CrmStatus.values) {
      stats[status] = 0;
    }
    for (final row in data) {
      final status = CrmStatus.values.firstWhere(
            (s) => s.name == row['status'],
        orElse: () => CrmStatus.lead,
      );
      stats[status] = (stats[status] ?? 0) + 1;
    }
    return stats;
  }



  // ──────────────── Quick Share ────────────────

  Future<void> upsertQuickShareSession(BusinessCard card) async {
    final user = currentUser;
    if (user == null) throw app.AuthException.notLoggedIn();

    final profile = await getUserProfile(user.id);
    await _client.from(SupabaseConstants.quickShareSessionsTable).upsert({
      'user_id': user.id,
      'card_id': card.id,
      'name': card.name ?? profile?.name,
      'company': card.company,
      'position': card.position,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeQuickShareSession() async {
    final userId = currentUser?.id;
    if (userId == null) return;

    await _client
        .from(SupabaseConstants.quickShareSessionsTable)
        .delete()
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> getActiveQuickSharePeers() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    final threshold = DateTime.now().subtract(const Duration(seconds: 10)).toIso8601String();
    final data = await _client
        .from(SupabaseConstants.quickShareSessionsTable)
        .select()
        .neq('user_id', userId)
        .gte('updated_at', threshold)
        .order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<String> createQuickShareExchangeRequest({
    required String toUserId,
    required BusinessCard fromCard,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw app.AuthException.notLoggedIn();

    final data = await _client.from(SupabaseConstants.quickShareExchangesTable).insert({
      'from_user_id': userId,
      'to_user_id': toUserId,
      'status': 'requested',
      'from_card': fromCard.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    }).select('id').single();

    return data['id'] as String;
  }

  Future<List<Map<String, dynamic>>> getIncomingQuickShareRequests() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from(SupabaseConstants.quickShareExchangesTable)
        .select()
        .eq('to_user_id', userId)
        .eq('status', 'requested')
        .order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> respondQuickShareExchange({
    required String exchangeId,
    required BusinessCard toCard,
  }) async {
    await _client
        .from(SupabaseConstants.quickShareExchangesTable)
        .update({
      'status': 'responded',
      'to_card': toCard.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', exchangeId);
  }

  Future<Map<String, dynamic>?> getQuickShareExchange(String exchangeId) async {
    final data = await _client
        .from(SupabaseConstants.quickShareExchangesTable)
        .select()
        .eq('id', exchangeId)
        .maybeSingle();

    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<void> completeQuickShareExchange(String exchangeId) async {
    await _client
        .from(SupabaseConstants.quickShareExchangesTable)
        .update({
      'status': 'completed',
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', exchangeId);
  }

  // ──────────────── Shared Links ────────────────

  /// 명함 공유 링크 생성 (shared_links 테이블에 저장)
  Future<String> createSharedLink(BusinessCard card) async {
    final userId = currentUser?.id;

    final data = await _client
        .from(SupabaseConstants.sharedLinksTable)
        .insert({
      'card_data': card.toJson(),
      'created_by': userId,
    })
        .select('id')
        .single();

    return data['id'] as String;
  }

  /// 공유 링크로 명함 데이터 조회
  Future<Map<String, dynamic>?> getSharedLink(String token) async {
    final data = await _client
        .from(SupabaseConstants.sharedLinksTable)
        .select('card_data, created_by')
        .eq('id', token)
        .maybeSingle();

    if (data == null) return null;
    return Map<String, dynamic>.from(data['card_data'] as Map);
  }

  // ──────────────── Storage ────────────────

  Future<String> uploadCardImage(String fileName, Uint8List bytes) async {
    final userId = currentUser?.id;
    if (userId == null) throw app.AuthException.notLoggedIn();

    final path = '$userId/$fileName';
    await _client.storage
        .from(SupabaseConstants.cardImagesBucket)
        .uploadBinary(path, bytes);
    return _client.storage
        .from(SupabaseConstants.cardImagesBucket)
        .getPublicUrl(path);
  }

  Future<void> deleteCardImage(String path) async {
    await _client.storage
        .from(SupabaseConstants.cardImagesBucket)
        .remove([path]);
  }
}