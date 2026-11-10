class BibleQuestion {
  final String prompt, topic, reference;
  final List<String> choices;
  // The source bank keeps the key internally; the assessment shuffles choices.
  const BibleQuestion(this.prompt, this.choices, this.topic, this.reference);
}

const assessmentNames = [
  'Beginner',
  'Elementary',
  'Intermediate',
  'Advanced',
  'In-depth'
];
const assessmentMinutes = [180, 150, 120, 90, 60];
const assessmentPassPercent = 80;

// Original English questions. References are for editorial validation only;
// result screens never expose answer keys or per-question correctness.
final assessmentBank = <List<BibleQuestion>>[
  _questions('''
Who built the ark before the flood?|Noah|Moses|Abraham|David|People|GEN.6.14
Which book opens the Bible?|Genesis|Exodus|Matthew|Psalms|Books|GEN.1.1
Who led Israel out of Egypt?|Moses|Joshua|Samuel|Solomon|People|EXO.3.10
Where was Jesus born?|Bethlehem|Nazareth|Jericho|Rome|Gospels|MAT.2.1
Who was the mother of Jesus?|Mary|Martha|Sarah|Ruth|Gospels|LUK.1.30-31
Who baptized Jesus?|John the Baptist|Peter|Paul|James|Gospels|MAT.3.13
What did Jesus feed to the five thousand, besides fish?|Bread|Grapes|Rice|Lentils|Gospels|MAT.14.17-21
Who defeated Goliath?|David|Saul|Jonathan|Solomon|People|1SA.17.49-50
Who was swallowed by a great fish?|Jonah|Elijah|Isaiah|Daniel|People|JON.1.17
Who was placed in a den of lions?|Daniel|Joseph|Nehemiah|Ezra|People|DAN.6.16
Which sea did Israel cross on dry ground after leaving Egypt?|The Red Sea|The Dead Sea|The Sea of Galilee|The Mediterranean Sea|Events|EXO.14.21-22
Who received the Ten Commandments on Mount Sinai?|Moses|Aaron|Caleb|Gideon|People|EXO.31.18
Which book contains the line about the Lord being a shepherd in chapter 23?|Psalms|Proverbs|Acts|Ruth|Books|PSA.23.1
Who denied knowing Jesus three times?|Peter|Andrew|Philip|Thomas|Gospels|MAT.26.69-75
Who betrayed Jesus to the chief priests?|Judas Iscariot|Nicodemus|Barnabas|Stephen|Gospels|MAT.26.14-16
On which day did Jesus rise, according to Luke's account of the empty tomb?|The first day of the week|The fourth day of the week|The sixth day of the week|The last day of the week|Gospels|LUK.24.1-6
Which book tells of the early church after Jesus' ascension?|Acts|Leviticus|Ecclesiastes|Malachi|Books|ACT.1.1-9
Who was Abraham's wife when Isaac was born?|Sarah|Rebekah|Rachel|Hannah|People|GEN.21.1-3
What did God create in Genesis 1:1?|The heavens and the earth|The ark|The tabernacle|The city of Jerusalem|Events|GEN.1.1
What command did Jesus give about one's neighbor?|Love your neighbor as yourself|Avoid every neighbor|Judge your neighbor's motives|Love only wealthy neighbors|Teachings|MAT.22.39
'''),
  _questions('''
Who interpreted Pharaoh's dreams about cows and grain?|Joseph|Benjamin|Esau|Laban|People|GEN.41.25-32
Who succeeded Moses as Israel's leader?|Joshua|Aaron|Eli|Boaz|People|JOS.1.1-2
Who was Ruth's mother-in-law?|Naomi|Deborah|Miriam|Esther|People|RUT.1.3-4
Who anointed David while Saul was still king?|Samuel|Nathan|Elisha|Zadok|People|1SA.16.13
What did Solomon ask God to give him to govern the people?|An understanding heart|A larger palace|Longer borders|More horses|Teachings|1KI.3.9
Who confronted the prophets of Baal on Mount Carmel?|Elijah|Elisha|Amos|Hosea|Events|1KI.18.20-24
Which queen approached the king on behalf of her endangered people?|Esther|Jezebel|Athaliah|Vashti|People|EST.4.14-16
Who led the rebuilding of Jerusalem's wall in the book bearing his name?|Nehemiah|Jonah|Nahum|Habakkuk|People|NEH.2.17-18
Where did Jesus perform the water-to-wine sign?|Cana|Bethany|Capernaum|Samaria|Gospels|JHN.2.1-11
Who climbed a sycamore tree to see Jesus?|Zacchaeus|Bartimaeus|Lazarus|Simeon|Gospels|LUK.19.2-4
In the Good Samaritan parable, who cared for the wounded traveler?|A Samaritan|The priest|The Levite|A tax collector|Teachings|LUK.10.30-35
In the lost-son parable, how did the father meet his returning younger son?|He ran to him and embraced him|He refused to see him|He sent him to prison|He demanded payment first|Teachings|LUK.15.20
Which sisters welcomed Jesus, with one sitting at his feet while the other served?|Mary and Martha|Rachel and Leah|Ruth and Orpah|Euodia and Syntyche|Gospels|LUK.10.38-42
Whom did Jesus call out of a tomb after four days?|Lazarus|Jairus|Nicodemus|Stephen|Gospels|JHN.11.17-44
Which disciple said he wanted to see Jesus' wounds before believing the resurrection report?|Thomas|Matthew|James|Simon the Zealot|Gospels|JHN.20.24-25
What happened to Saul on the road to Damascus?|He encountered the risen Jesus|He met Pharaoh|He rebuilt the temple|He became king of Judea|Events|ACT.9.3-6
Who was the first Christian martyr described in Acts?|Stephen|Timothy|Silas|Titus|People|ACT.7.59-60
Who accompanied Paul in prison at Philippi, praying and singing hymns?|Silas|Mark|Apollos|Luke|Events|ACT.16.25
According to Ephesians 6, what is called the sword of the Spirit?|The word of God|Political influence|Personal wealth|Human anger|Teachings|EPH.6.17
According to 1 Corinthians 13, which is greatest among faith, hope, and love?|Love|Hope|Faith|None is named greatest|Teachings|1CO.13.13
'''),
  _questions('''
What did the Passover blood on doorposts signify in Exodus 12?|A sign for the households to be passed over|A military rank|A royal tax payment|A sign that a house was empty|Context|EXO.12.13
Why did Israel make a bronze serpent in Numbers 21?|So those bitten could look at it and live|To crown a new king|To store grain|To replace the tabernacle|Context|NUM.21.8-9
What did Hannah do after Samuel was weaned?|She brought him to serve the Lord|She made him king|She sent him to Egypt|She appointed him a soldier|People|1SA.1.24-28
What was Nathan's story about when confronting David in 2 Samuel 12?|A rich man taking a poor man's lamb|A lost coin|A vineyard's unpaid workers|A merchant finding a pearl|Context|2SA.12.1-7
What did the Lord require in Micah 6:8?|Do justice, love kindness, and walk humbly with God|Acquire land and horses|Offer gifts without justice|Avoid all contact with others|Teachings|MIC.6.8
What is the new covenant promise in Jeremiah 31 concerning God's law?|God will write it on their hearts|It will be destroyed|It will be restricted to kings|It will be sold to other nations|Teachings|JER.31.31-33
What image does Ezekiel 37 use for the restoration of Israel?|Dry bones coming to life|A tower reaching heaven|A basket of bread|A buried talent|Context|EZK.37.1-14
What did Jesus resist during his wilderness temptations?|The devil's proposals to depart from obedience to God|John's baptism|The call to pray|The command to love God|Gospels|MAT.4.1-11
In Matthew 7, what distinguishes the wise builder?|Hearing Jesus' words and doing them|Building the largest house|Avoiding all storms|Hearing without acting|Teachings|MAT.7.24-27
In Mark 2, what did Jesus say the Sabbath was made for?|Humankind|Only the temple building|Only rulers|The exclusion of sick people|Teachings|MRK.2.27
Why did Jesus tell the parable of the persistent widow in Luke 18?|To encourage prayer without losing heart|To explain harvest seasons|To teach temple measurements|To predict a census|Context|LUK.18.1
In John 15, how can the branches bear fruit?|By remaining in Jesus|By separating from the vine|By trusting their own status|By competing with other branches|Teachings|JHN.15.4-5
What did Peter learn through the events involving Cornelius in Acts 10?|God shows no partiality|Gentiles could never receive God's message|Only Jerusalem had believers|Prayer was unnecessary|Context|ACT.10.34-35
What was the central dispute addressed at the Jerusalem council in Acts 15?|Whether Gentile believers must be circumcised and keep the law of Moses|Which emperor to support|Where to build Noah's ark|Who should replace David|Context|ACT.15.5-6
According to Romans 12, how should believers respond to evil?|Overcome evil with good|Repay every insult|Seek revenge immediately|Approve every harmful act|Teachings|ROM.12.19-21
What does Paul compare the church to in 1 Corinthians 12?|One body with many members|A single isolated stone|An army with no leader|A vineyard without branches|Teachings|1CO.12.12-27
What does Galatians 5 call love, joy, peace, and related qualities?|The fruit of the Spirit|The armor of Rome|The gifts of Pharaoh|The wages of trade|Teachings|GAL.5.22-23
In Philippians 2, whose humility is presented as the example for believers?|Christ Jesus|Herod|Pilate|Caesar|Teachings|PHP.2.5-8
What does James teach about faith without works?|It is dead|It is complete in every sense|It removes the need for compassion|It is the only kind of faith mentioned|Teachings|JAS.2.17
In Revelation 21, what is said about death in the new creation?|It will be no more|It will govern every city|It will replace worship|It will increase without end|Teachings|REV.21.4
'''),
  _questions('''
In Genesis 15:6, how is Abram's belief described?|It was counted to him as righteousness|It made him king of Egypt|It ended every future trial|It built the tower of Babel|Context|GEN.15.6
In Exodus 19, what calling is given to Israel before the covenant commands?|A kingdom of priests and a holy nation|A kingdom without obligations|A replacement for every nation|A people forbidden to worship|Context|EXO.19.5-6
What happened on the fiftieth year described in Leviticus 25?|Jubilee was proclaimed|A new ark was built|The Red Sea was crossed again|A king was chosen by lot|Context|LEV.25.10
Why were cities of refuge provided in Numbers 35?|Protection for a person who killed unintentionally pending judgment|Storage for royal treasure|Training grounds for cavalry|Places to avoid all trials|Context|NUM.35.11-12
What warning does Deuteronomy 8 give concerning prosperity?|Do not forget the Lord and credit only your own strength|Prosperity removes the need for obedience|Wealth proves every decision is right|Only kings may give thanks|Context|DEU.8.11-18
What covenant promise is made about David's house in 2 Samuel 7?|His house and kingdom would be established before God|Every descendant would act without sin|David would build every future temple|Israel would never face discipline|Context|2SA.7.12-16
In 1 Kings 19, what followed the wind, earthquake, and fire in Elijah's encounter?|A quiet, gentle sound|A new flood|An army from Egypt|A royal coronation|Context|1KI.19.11-12
What does Job do at the end of God's speeches in Job 42:1-6?|He acknowledges God's power and his own limited understanding|He claims complete knowledge|He declares God powerless|He demands the throne|Context|JOB.42.1-6
How does Psalm 73's speaker begin to understand the apparent success of the wicked?|By entering God's sanctuary and considering their end|By becoming their ruler|By abandoning worship permanently|By measuring their houses|Context|PSA.73.16-17
In Isaiah 6, what response follows the prophet's cleansing and God's call?|He offers to be sent|He asks to become king|He builds a golden calf|He returns to Egypt|Context|ISA.6.6-8
What does Hosea 6:6 emphasize over sacrifice?|Steadfast love and knowledge of God|Military conquest|The size of offerings|Royal ancestry|Teachings|HOS.6.6
In Habakkuk 3, what does the prophet resolve despite agricultural loss?|To rejoice in the Lord|To stop praying forever|To trust only in horses|To abandon every neighbor|Teachings|HAB.3.17-18
In Matthew 18, what begins the process for addressing a fellow disciple's sin?|A private conversation with that person|Immediate public humiliation|A demand for payment|A report to every village|Teachings|MAT.18.15
Why did Jesus wash his disciples' feet in John 13?|To give an example of humble service|To appoint a Roman governor|To replace every form of prayer|To rank them by wealth|Gospels|JHN.13.12-15
What reason does Luke give for writing his orderly account?|That Theophilus may know the certainty of what he was taught|To publish Roman tax records|To replace the Psalms|To appoint a high priest|Context|LUK.1.1-4
What issue did the daily distribution dispute in Acts 6 reveal?|Some widows were being neglected|There was no need for service|The apostles had stopped believing|Every believer owned a palace|Context|ACT.6.1
In Romans 14, what concern shapes Paul's teaching on disputed food practices?|Avoiding judgment and not causing another believer to stumble|Forcing one menu on everyone|Ending all meals together|Making food the basis of God's kingdom|Teachings|ROM.14.13-19
Why did Paul sometimes work with his own hands, according to 1 Corinthians 9?|To offer the gospel without charge|To stop proclaiming the gospel|To become a temple priest|To purchase Roman citizenship|Context|1CO.9.12-18
In 2 Corinthians 8, what does Paul cite as a pattern of generous self-giving?|Christ becoming poor for others' sake|Pharaoh's building projects|Herod's banquet|The tower of Babel|Teachings|2CO.8.9
What does Hebrews 4 invite believers to approach with confidence?|The throne of grace|The palace of Caesar|The market gate|The tower of Babel|Teachings|HEB.4.14-16
'''),
  _questions('''
Why does Paul refer to Abraham in Romans 4:9-12?|To discuss righteousness by faith before circumcision|To prove Abraham was a Roman|To identify him as a temple builder|To establish a new census|Connections|ROM.4.9-12
What shared image connects Numbers 21:8-9 with John 3:14-15?|The lifting up of the serpent and the lifting up of the Son of Man|The rebuilding of Jerusalem's wall|The crossing of the Jordan|The fall of Jericho|Connections|JHN.3.14-15
What does Matthew 12:7 use Hosea 6:6 to emphasize?|Mercy in a dispute about condemning the guiltless|The end of every moral obligation|The value of military strength|The need to rebuild Babylon|Connections|MAT.12.1-8
In Luke 4, how does Jesus relate Isaiah's proclamation to his hearers?|He says the Scripture is fulfilled in their hearing|He says it concerns only farming|He says he has never read it|He changes the subject to taxes|Connections|LUK.4.16-21
What does Jesus identify as the greatest commandment in Mark 12?|Love God with all your heart, soul, mind, and strength|Build a larger storehouse|Seek the highest seat|Avoid every outsider|Connections|MRK.12.28-31
In Acts 2, why does Peter cite Joel?|To explain the outpouring of the Spirit|To explain Roman citizenship|To set temple tax rates|To choose a replacement for Moses|Connections|ACT.2.16-18
How is Jesus described in relation to Psalm 118's rejected stone in Acts 4?|The rejected stone that became the cornerstone|A stone never used in building|A replacement for the Roman roads|A stone hidden by Pharaoh|Connections|ACT.4.10-11
What does Hebrews 8 quote Jeremiah 31 to discuss?|The promised new covenant|The dimensions of Noah's ark|The exile of Jonah|The reign of Ahab|Connections|HEB.8.8-12
In Hebrews 11, what connects the people named in the chapter?|Faith expressed through their varied responses to God|A shared earthly occupation|Residence in the same city|Uninterrupted earthly success|Context|HEB.11.1-40
How does James 2 use Abraham's offering of Isaac in its argument?|As an example of faith working with actions|As proof that faith has no role|As a command to repeat the event|As a lesson on royal taxes|Connections|JAS.2.21-23
What does 1 Peter 2:9 call its readers, echoing Israel's covenant language?|A royal priesthood and a holy nation|A replacement Roman senate|A people with no calling|A secret trading guild|Connections|1PE.2.9
What image in Revelation 22 echoes the garden and life imagery of Genesis?|The tree of life beside the river|A golden calf on a mountain|A tower of brick|A chariot race|Connections|REV.22.1-2
Why does Paul distinguish members' gifts in Romans 12?|So gifts are used humbly in service within one body|So everyone competes for the same role|So no one serves others|So wealth determines all leadership|Teachings|ROM.12.3-8
What problem does Paul correct concerning the Lord's Supper in 1 Corinthians 11?|Divisions and humiliating those who have little|Too much concern for the poor|Reading Scripture before eating|Inviting believers to gather|Context|1CO.11.17-22
In Philippians 3, what does Paul do with former grounds for confidence?|Counts them as loss compared with knowing Christ|Treats them as greater than Christ|Uses them to purchase salvation|Hides them to become a king|Context|PHP.3.4-9
In Colossians 3, what accompanies putting on compassion, kindness, and humility?|Forgiving one another and putting on love|Returning evil for evil|Ranking believers by wealth|Abandoning gratitude|Teachings|COL.3.12-15
What balance does 2 Thessalonians 3:10-13 present?|Responsibility in work alongside not growing weary in doing good|A ban on all assistance|A command to abandon work|A promise that work eliminates suffering|Context|2TH.3.10-13
What does 2 Timothy 3:16-17 say Scripture equips God's servant for?|Every good work|Predicting every personal event|Avoiding all correction|Winning every political office|Teachings|2TI.3.16-17
In Philemon, how does Paul ask that Onesimus be received?|As a beloved brother|As a foreign king|As a high priest|As a military commander|Context|PHM.1.15-17
What does Revelation 7:9 portray about the multitude before the throne?|People from every nation, tribe, people, and language|Only one earthly occupation|A gathering limited to one city|An army praising Caesar|Teachings|REV.7.9
'''),
];

List<BibleQuestion> _questions(String source) => [
      for (final line in source.trim().split('\n'))
        if (line.trim().isNotEmpty)
          (() {
            final parts = line.trim().split('|');
            return BibleQuestion(
                parts[0], parts.sublist(1, 5), parts[5], parts[6]);
          })(),
    ];
