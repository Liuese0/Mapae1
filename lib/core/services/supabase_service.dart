import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../constants/supabase_constants.dart';
import '../../features/shared/models/app_user.dart';
import '../../features/shared/models/business_card.dart';
import '../../features/shared/models/collected_card.dart';
import '../../features/shared/models/category.dart';
import '../../features/shared/models/team.dart';
import '../../features/shared/models/context_tag.dart';

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
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.namecard.app://login-callback',
    ) as AuthResponse;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// 로그인 후 프로필이 없으면 자동 생성
  Future<AppUser> ensureUserProfile() async {
    final user = currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');

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
      }) async {
    var query = _client
        .from(SupabaseConstants.collectedCardsTable)
        .select()
        .eq('user_id', userId);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    final data = await query.order(sortBy, ascending: ascending);
    return data.map((json) => CollectedCard.fromJson(json)).toList();
  }

  Future<CollectedCard> addCollectedCard(CollectedCard card) async {
    final data = await _client
        .from(SupabaseConstants.collectedCardsTable)
        .insert(card.toJson())
        .select()
        .single();
    return CollectedCard.fromJson(data);
  }

  Future<CollectedCard> updateCollectedCard(CollectedCard card) async {
    final data = await _client
        .from(SupabaseConstants.collectedCardsTable)
        .update(card.toJson())
        .eq('id', card.id)
        .select()
        .single();
    return CollectedCard.fromJson(data);
  }

  Future<void> deleteCollectedCard(String cardId) async {
    await _client
        .from(SupabaseConstants.collectedCardsTable)
        .delete()
        .eq('id', cardId);
  }

  Future<int> getCollectedCardCount(String userId) async {
    final result = await _client
        .from(SupabaseConstants.collectedCardsTable)
        .select()
        .eq('user_id', userId)
        .count(CountOption.exact);
    return result.count;
  }

  // ──────────────── Categories ────────────────

  Future<List<CardCategory>> getCategories(String userId) async {
    final data = await _client
        .from(SupabaseConstants.categoriesTable)
        .select()
        .eq('user_id', userId)
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
    // 새 오너로 변경
    await _client
        .from(SupabaseConstants.teamMembersTable)
        .update({'role': TeamRole.owner.name})
        .eq('team_id', teamId)
        .eq('user_id', newOwnerId);

    // 기존 오너를 멤버로 변경
    await _client
        .from(SupabaseConstants.teamMembersTable)
        .update({'role': TeamRole.member.name})
        .eq('team_id', teamId)
        .eq('user_id', currentOwnerId);

    // teams 테이블의 owner_id도 변경
    await _client
        .from(SupabaseConstants.teamsTable)
        .update({'owner_id': newOwnerId})
        .eq('id', teamId);
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

  /// 명함을 팀에 공유 (스냅샷 저장 — 원본 삭제 시에도 유지)
  Future<void> shareCardToTeam(String cardId, String teamId) async {
    final userId = currentUser?.id;

    // 원본 명함 데이터를 가져와 스냅샷으로 저장
    final cardData = await _client
        .from(SupabaseConstants.collectedCardsTable)
        .select()
        .eq('id', cardId)
        .single();

    await _client.from(SupabaseConstants.teamSharedCardsTable).insert({
      'card_id': cardId,
      'team_id': teamId,
      'shared_by': userId,
      'shared_at': DateTime.now().toIso8601String(),
      'name': cardData['name'],
      'company': cardData['company'],
      'position': cardData['position'],
      'department': cardData['department'],
      'email': cardData['email'],
      'phone': cardData['phone'],
      'mobile': cardData['mobile'],
      'fax': cardData['fax'],
      'address': cardData['address'],
      'website': cardData['website'],
      'sns_url': cardData['sns_url'],
      'memo': cardData['memo'],
      'image_url': cardData['image_url'],
    });
  }

  Future<void> unshareCardFromTeam(String sharedCardId) async {
    await _client
        .from(SupabaseConstants.teamSharedCardsTable)
        .delete()
        .eq('id', sharedCardId);
  }

  /// 팀 공유 명함 목록 (스냅샷 데이터에서 직접 읽기)
  Future<List<Map<String, dynamic>>> getTeamSharedCards(String teamId) async {
    final data = await _client
        .from(SupabaseConstants.teamSharedCardsTable)
        .select()
        .eq('team_id', teamId)
        .order('shared_at', ascending: false);
    return data;
  }

  /// 공유된 명함을 내 지갑으로 복사
  Future<CollectedCard> copySharedCardToWallet(Map<String, dynamic> sharedCard) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다.');

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

  // ──────────────── Storage ────────────────

  Future<String> uploadCardImage(String fileName, Uint8List bytes) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다.');

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