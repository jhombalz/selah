class PassageCard {
  final String id, theme, title, reference, context, question, prayer, action;
  const PassageCard(this.id, this.theme, this.title, this.reference,
      this.context, this.question, this.prayer, this.action);
}

const growthCatalogVersion = 1;
const growthContentAuthor = 'SELAH original editorial content';

const growthThemes = ['Anxiety', 'Stress', 'Grief', 'Loneliness', 'Joy'];
// Original SELAH prompts. Editorial guidance, not Scripture or a clinical assessment.
// Context checked against the surrounding chapters; no external devotional text.
const growthCatalog = [
  PassageCard(
      'anxiety-requests',
      'Anxiety',
      'Bring your requests',
      'PHP.4.4-9',
      'Paul writes to a church community about rejoicing, gentleness, prayer, and the things they give their attention to. Read these invitations together.',
      'What concern could you bring honestly to God, alongside something you are thankful for?',
      'God, here is what is on my mind. Help me bring it to You honestly and notice what is good.',
      'Write down one concern and one reason for gratitude.'),
  PassageCard(
      'anxiety-today',
      'Anxiety',
      'Attend to today',
      'MAT.6.25-34',
      'In the Sermon on the Mount, Jesus speaks about daily needs, the Father’s care, and seeking God’s kingdom. Read the passage as an invitation to trust, not a judgment on your feelings.',
      'What is one thing you can attend to today while entrusting tomorrow to God?',
      'Father, You know my needs. Help me take today’s next faithful step.',
      'Choose one manageable task for today.'),
  PassageCard(
      'anxiety-cares',
      'Anxiety',
      'You can bring your cares',
      '1PE.5.6-11',
      'Peter encourages believers facing suffering with humility, watchfulness, care for one another, and hope in God. The passage does not pretend hardship is absent.',
      'Which care have you been carrying alone?',
      'God, I bring You this care. Help me receive support and hold on to hope.',
      'Consider asking a trusted person for support.'),
  PassageCard(
      'stress-rest',
      'Stress',
      'An invitation to rest',
      'MAT.11.25-30',
      'Jesus invites the weary to come to Him and learn from Him. Notice both the invitation to rest and the invitation to become His learner.',
      'What burden can you name, and what might learning from Jesus look like today?',
      'Jesus, I am weary. Teach me Your gentleness as I come to You.',
      'Make room for a short, unhurried pause.'),
  PassageCard(
      'stress-quiet',
      'Stress',
      'Be still before God',
      'PSA.46.1-11',
      'This psalm describes upheaval and conflict while confessing God as refuge. Read its stillness in the setting of a world that feels unsettled.',
      'What feels unsettled, and what does this psalm invite you to remember?',
      'God, be my refuge in what I cannot control. Help me be present with You.',
      'Pause one unnecessary demand today if you can.'),
  PassageCard(
      'stress-return',
      'Stress',
      'Return to a quiet place',
      'MRK.6.30-44',
      'After the apostles return from their work, Jesus invites them to rest. The story continues with His compassion for a crowd and the feeding of many people.',
      'What do you notice about rest and compassion in this story?',
      'Jesus, help me recognize my limits and respond to others with compassion.',
      'Plan a realistic time to rest.'),
  PassageCard(
      'grief-tears',
      'Grief',
      'Jesus meets sorrow',
      'JHN.11.17-37',
      'In the account of Lazarus, Jesus meets Martha and Mary in their grief and weeps. Read the conversation slowly without rushing past their sorrow.',
      'What sorrow or question would you like to bring to Jesus?',
      'Jesus, meet me in my sorrow. I bring You what I cannot put right.',
      'Give yourself permission to name a loss without solving it.'),
  PassageCard(
      'grief-lament',
      'Grief',
      'Room for lament',
      'PSA.13.1-6',
      'The psalmist asks how long, brings a direct plea to God, and speaks of trust. Notice that honest questions belong in this prayer.',
      'What would your own “How long?” prayer say?',
      'God, hear my honest questions. Stay with me as I bring them to You.',
      'Write a few honest lines of lament.'),
  PassageCard(
      'grief-comfort',
      'Grief',
      'Comfort received and shared',
      '2CO.1.3-11',
      'Paul describes affliction, God’s comfort, dependence on God, and the prayers of others. Comfort here is shared through a community, not kept private.',
      'Where might you receive comfort, or gently offer it?',
      'God of comfort, help me receive care and be attentive to someone else’s pain.',
      'Reach out to a trusted person, or check on someone who is grieving.'),
  PassageCard(
      'loneliness-known',
      'Loneliness',
      'Known by God',
      'PSA.139.1-12',
      'The psalmist reflects on being known by God and on God’s presence in every place. Read the images of distance and darkness in their poetic setting.',
      'Which image in the passage speaks to your sense of being known?',
      'God, help me bring my loneliness into Your presence.',
      'Write down one person you could contact this week.'),
  PassageCard(
      'loneliness-presence',
      'Loneliness',
      'Peace in a difficult time',
      'JHN.14.15-27',
      'In His farewell conversation, Jesus speaks to His disciples about love, the Spirit, and peace as they face His departure.',
      'What do you notice about Jesus’ words to people facing separation?',
      'Jesus, help me listen to Your words and welcome companionship in this season.',
      'Send a simple message to someone you trust.'),
  PassageCard(
      'loneliness-community',
      'Loneliness',
      'Encourage one another',
      'HEB.10.19-25',
      'This passage connects drawing near to God with holding on to hope and encouraging one another in love and good works.',
      'What small step toward a caring community feels possible?',
      'God, help me draw near to You and make room for others.',
      'Consider joining a trusted gathering or inviting someone for a conversation.'),
  PassageCard(
      'joy-thanks',
      'Joy',
      'Enter with thanksgiving',
      'PSA.100.1-5',
      'This short communal psalm invites worship and thanksgiving in response to who God is. Read it as a shared song of praise.',
      'What would you like to thank God for today?',
      'God, thank You for Your goodness. Help me notice and share gratitude.',
      'Tell someone specifically why you appreciate them.'),
  PassageCard(
      'joy-abide',
      'Joy',
      'Remain in love',
      'JHN.15.1-17',
      'Jesus uses the image of a vine and branches, then speaks about remaining in His love, joy, and loving one another.',
      'How are love, remaining, and joy connected in this passage?',
      'Jesus, help me remain in Your love and express it to someone today.',
      'Choose one practical act of love.'),
  PassageCard(
      'joy-remember',
      'Joy',
      'Remember His benefits',
      'PSA.103.1-14',
      'The psalmist calls on his whole being to bless God and remember mercy and compassion. Read the reasons for praise rather than forcing a feeling.',
      'What kindness or mercy would you like to remember?',
      'God, help me remember Your compassion and respond with gratitude.',
      'Record one kindness you do not want to forget.'),
];

PassageCard? growthCard(String? id) {
  for (final card in growthCatalog) {
    if (card.id == id) return card;
  }
  return null;
}

PassageCard chooseGrowthCard(String theme, Map<String, DateTime> seen) {
  final cards = growthCatalog.where((card) => card.theme == theme).toList();
  if (cards.isEmpty) throw ArgumentError('Unknown theme');
  cards.sort((a, b) =>
      (seen[a.id] ?? DateTime(1970)).compareTo(seen[b.id] ?? DateTime(1970)));
  return cards.first;
}
