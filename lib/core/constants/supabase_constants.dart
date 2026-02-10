class SupabaseConstants {
  SupabaseConstants._();

  // Table names
  static const String usersTable = 'users';
  static const String myCardsTable = 'my_cards';
  static const String collectedCardsTable = 'collected_cards';
  static const String categoriesTable = 'categories';
  static const String teamsTable = 'teams';
  static const String teamMembersTable = 'team_members';
  static const String teamSharedCardsTable = 'team_shared_cards';
  static const String contextTagsTable = 'context_tags';
  static const String tagTemplatesTable = 'tag_templates';
  static const String teamInvitationsTable = 'team_invitations';
  static const String tagTemplateFieldsTable = 'tag_template_fields';
  static const String tagValuesTable = 'tag_values';

  // Storage buckets
  static const String cardImagesBucket = 'card-images';
  static const String profileImagesBucket = 'profile-images';
}