// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.

string cvs_version = "$Id: deepthought.pike,v 1.3 1998/03/11 19:42:45 neotron Exp $";
// This module should have the strings in a separate file.. :)
#include <module.h>
inherit "module";

string *thoughts = ({
"A funny thing to do is, if you're out hiking and your friend gets "
"bitten by a poisonous snake, tell him you're going to go for help,u "
"then go about ten feet and pretend that you got bit by a snake. Then "
"start an argument with him about who's going to go get help. A lot of "
"guys will start crying. That's why it makes you feel good when you "
"tell them it was just a joke. ", 

"A man doesn't automatically get my respect. He has to get down in the "
"dirt and beg for it. ",
"Any man, in the right situation, is capable of murder. But not any "
"man is capable of being a good camper. So, murder and camping are not "
"as similar as you might think. ",
"Anytime I see something screech across a room and latch onto "
"someone's neck, and the guy screams and tries to get it off, I have to "
"laugh, because what is that thing? ",
"As I bit into the nectarine, it had a crisp juiciness about it that "
"was very pleasurable until I realized it wasn't a nectarine at all, "
"but a HUMAN HEAD!! ",
"As the evening sun faded from a salmon color to a sort of flint gray, "
"I thought back to the salmon I caught that morning, and how gray he "
"was, and how I named him Flint. ",
"As the snow started to fall, he tugged his coat tighter around "
"himself. Too tight, as it turned out. \"This is the fourth coat "
"crushing this year\", said the sergeant as he outlined the body with a "
"special pencil that writes on snow. ",
"As we were driving, we saw a sign that said \"Watch for Rocks.\" "
"Marta said it should read \"Watch for Pretty Rocks.\" I told her she "
"should write in her suggestion to the highway department, but she "
"started saying it was a joke just to get out of writing a simple "
"letter. And I thought I was lazy! ",
"Better not take a dog on the Space Shuttle, because if he sticks his "
"head out when you're coming home his face might burn up. ", 

"Blow ye winds Like the trumpet blows; but without that noise. ",
"Contrary to popular belief, the most dangerous animal is not the lion "
"or tiger or even the elephant. The most dangerous animal is a shark "
"riding on an elephant, just trampling and eating everything they "
"see. ",
"Even though he was an enemy of mine, I had to admit that what he had "
"accomplished was a brilliant piece of strategy. First, he punched me, "
"then he kicked me, and then he punched me again. ", 

"Fear can sometimes be a useful emotion. For instance, let's say "
"you're an astronaut on the moon and you fear that your partner has "
"been turned into Dracula. The next time he goes out for the moon "
"pieces, wham!, you just slam the door behind him and blast off. He "
"might call you on the radio and say he's not Dracula, but you just "
"say, \"Think again, bat man.\" ",
"Folks still remember the day ole Bob Riley came bouncing down that "
"dirt road in his pickup. Pretty soon, it was bouncing higher and "
"higher. The tires popped, and the shocks broke, but that truck kept "
"bouncing. Some say it bounced clean over the moon, but whoever says "
"that is a goddamn liar. ",
"He was a cowboy mister, and he loved the land. He loved it so much "
"that he made a woman out of dirt and married her. But when he kissed "
"her, she disintegrated. Later, at the funeral, when the preacher said "
"\"Dust to dust,\" some people laughed, and the cowboy shot them. At "
"his hanging, he told the others, \"I'll be waiting for you in Heaven "
"with a gun!\" ",
"He was the kind of man who was not ashamed to show affection. I guess "
"that's what I hated about him. ",
"Here's a good joke to do during an earthquake: Straddle a big crack "
"in the earth, and if it opens wider, go, \"Whoa! Whoa!\" and flail "
"your arms around, as if you're going to fall in. ",
"Here's a good trick: Get a job as a judge at the Olympics. Then, if "
"some guy sets a world record, pretend that you didn't see it and go, "
"\"Okay, is everybody ready to start now?\" ",
"I bet a funny thing would be to go way back in time to where there "
"was going to be an eclipse and tell the cave men, \"If I have to come "
"to destroy you, may the sun be blotted out from the sky.\" Just then "
"the eclipse would start, and they'd probably try to kill you or "
"something, but then you could explain about the rotation of the moon "
"and all, and everyone would get a good laugh. ",
"I bet for an Indian, shooting an old fat pioneer woman in the back "
"with an arrow, and she fires her shotgun into the ground as she falls "
"over, is like the top thing you can do. ", 

"I bet it was pretty hard to pick up girls if you had the Black Death. ",
"I bet one legend that keeps recurring throughout history, in every "
"culture, is the story of Popeye. ",
"I bet the main reason the police keep people away from a plane crash "
"is they don't want anybody walking in and lying down in the crash "
"stuff, then when somebody comes up act like they just woke up and go, "
"\"What was that?!\" ",
"I can see why it would be prohibited to throw most things off the top "
"of the Empire State Building, but what's wrong with little bits of "
"cheese? They probably break down into their various gasses before they "
"even hit. ",
"I can still recall old Mister Barnslow getting out every morning and "
"nailing a fresh load of tadpoles to that old board of his. Then he'd "
"spin it round and round, like a wheel of fortune, and no matter where "
"it stopped he'd yell out, \"Tadpoles! Tadpoles is a winner!\" We all "
"thought he was crazy. But then, we had some growing up to do. ",
"I don't understand people who say life is a mystery, because what is "
"it they want to know? ",
"I guess I kinda lost control, because in the middle of the play I ran "
"up and lit the evil puppet villain on fire. No, I didn't. Just "
"kidding. I just said that to help illustrate one of the human "
"emotions, which is freaking out. Another emotion is greed, as when you "
"kill someone for money, or something like that. Another emotion is "
"generosity, as when you pay someone double what he paid for his stupid "
"puppet. ",
"I guess more bad things have been done in the name of progress than "
"any other. I myself have been guilty of this. When I was a teen-ager, "
"I stole a car and drove it out into the desert and set it on "
"fire. When the police showed up, I just shrugged and said, \"Hey, "
"progress.\" Boy, did I have a lot to learn. ",
"I guess of all my uncles, I liked Uncle Cave Man the best. We called "
"him Uncle Cave Man because he lived in a cave and every once in a "
"while, he'd eat one of us. Later we found out that he was a bear. ",
"I have to laugh when I think of the first cigar, because it was "
"probably just a bunch of rolled-up tobacco leaves. ",
"I hope if dogs ever take over the world, and they choose a king, they "
"don't just go by size, because I bet there are some Chihuahuas with "
"some good ideas. ",
"I hope in the future Americans are thought of as a warlike, vicious "
"people, because I bet a lot of high schools would pick \"Americans\" "
"as their mascot. ",
"I hope, when they die, cartoon characters have to answer for their "
"sins. ",
"I read that when the archaeologists dug down into the ancient "
"cemetary, they found fragments of human bones! What kind of barbarians "
"were these people, anyway? ",
"I remember that fateful day when Coach took me aside. I knew what was "
"coming. \"You don't have to tell me,\" I said. \"I'm off the team, "
"aren't I?\" \"Well,\" said Coach, \"you never were really on the "
"team. You made that uniform you're wearing out of rags and towels, and "
"your helmet is a toy space helmet. You show up at practice and then "
"either steal the ball and make us chase you to get it back, or you try "
"to tackle people at inappropriate times.\" It was all true what he was "
"saying. And yet, I thought, something is brewing inside the head of "
"this Coach. He sees something in me, some kind of raw talent that he "
"can mold. But that's when I felt the handcuffs go on. ",
"I saw on this nature show how the male elk douses himself with urine "
"to smell sweeter to the opposite sex. What a coincidence! ",
"I scrambled to the top of the precipice where Nick was "
"waiting. \"That was fun,\" I said. \"You bet it was\", said "
"Nick. \"Lets climb higher.\" \"No,\" I said. \"I think we should be "
"heading back now.\" \"We have time,\" Nick insisted. I said we didn't, "
"and Nick said we did. We argued back and forth like that for about 20 "
"minutes, then finally decided to head back. ",
"I think a good gift for the president would be a chocolate "
"revolver. And since he's so busy, you'd probably have to run up to him "
"and hand it to him. ",
"I think a good movie would be about a guy who's a brain scientist, "
"but he gets hit on the head and it damages the part of the brain that "
"makes you want to study the brain. ",
"I think a good product would be \"Baby Duck Hat\". It's a fake baby "
"duck, which you strap on top of your head. Then you go swimming "
"underwater until you find a mommy duck and her babies, and you join "
"them. Then, all of a sudden, you stand up out of the water and roar "
"like Godzilla. Man, those ducks really take off! Also, Baby Duck Hat "
"is good for parties. ", " " "I think a good way to get into a movie is "
"to show up where they're making the movie, then stick a big cactus "
"plant into your buttocks and start yowling and running around, "
"Everyone would think it was funny, and the head movie guy would say, "
"\"Hey, let's put him in the movie.\" ",
"I think college administrators should encourage students to urinate "
"on walls and bushes, because then when students from another college "
"come sniffing around, they'll know this is someone else's "
"territory. ",
"I think in one of my previous lives I was a mighty king, because I "
"like people to do what I say. ",
"I think man invented the car by instinct. ",
"I think my new thing will be to try to be a real happy guy. I'll just "
"walk around being real happy until some jerk says something stupid to "
"me. ",
"I think somebody should come up with a way to breed a very large "
"shrimp. That way, you could ride him, then, after you camped at night, "
"you could eat him. How about it, science? ",
"I think the monkeys at the zoo should have to wear sunglasses so they "
"can't hypnotize you. ",
"I think there should be something in science called the \"reindeer "
"effect.\" I don't know what it would be, but I think it'd be good to "
"hear someone say, \"Gentlemen, what we have here is a terrifying "
"example of the reindeer effect.\" ",
"I think they should continue the policy of not giving a Nobel Prize "
"for paneling. ",
"I wish a robot would get elected President. That way, when he came to "
"town, we could all take a shot at him and not feel bad. ",
"I wish I had a kryptonite cross, because then you could keep both "
"Dracula and Superman away. ",
"I wish I lived back in the old west days, because I'd save up my "
"money for about twenty years so I could buy a solid-gold pick. Then "
"I'd go out West and start digging for gold. When someone came up and "
"asked what I was doing, I'd say, \"Looking for gold, ya durn fool.\" "
"He'd say, \"Your pick is gold,\" and I'd say, \"Well, that was easy.\" "
"Good joke, huh. ",
"I wish scientists would come up with a way to make dogs a lot bigger, "
"but with a smaller head. That way, they'd still be good as watchdogs, "
"but they wouldn't eat so much. ",
"I wonder if angels believe in ghosts. ",
"I wouldn't be surprised if someday some fisherman caught a big shark "
"and cut it open, and there inside was a whole person. Then they cut "
"the person open, and in him is a little baby shark. And in the baby "
"shark there isn't a person, because it would be too small. But there's "
"a little doll or something, like a Johnny Combat little toy guy "
"something like that. ",
"I'd like to see a nude opera, because when they hit those high notes "
"I bet you can really see it in those genitals. ",
"I'll be the first to admit that my idea of God is pretty different. I "
"believe in a God with a long white beard, a gold crown, and a long "
"robe with lots of shiny jewels on it. He sits on a big throne in the "
"clouds, and He's about five hundred feet tall. He talks in a real deep "
"voice like \"I...AM...GOD!\" He can blow up stuff just by looking at "
"it. This is my own, personal idea of God. ",
"If God dwells inside us, like some people say, I sure hope he likes "
"enchiladas, because that's what He's getting! ",
"If I ever do a book on the Amazon, I hope I am able to bring a "
"certain lightheartedness to the subject, in a way that tells the "
"reader we are going to have fun with this thing. ",
"If I ever opened a trampoline store, I don't think I'd call it "
"Trampo-Land, because you might think it was a store for tramps, which "
"is not the impression we are trying to convey with our store. On the "
"other hand, we would not prohibit tramps from browsing, or testing the "
"trampolines, unless his gyrations seemed to be getting out of "
"control. ",
"If I had a mine shaft, I don't think I would just abandon it. There's "
"got to be a better way. ",
"If I had a nickname, I think I would want it to be \"Prince of "
"Weasels\", because then I could go up and bite people and they would "
"turn around and go, \"What the?\" And then they would recognize me, "
"and go, \"Oh, it's you, the Prince of Weasels.\" ",
"If the Vikings were around today, they would probably be amazed at "
"how much glow-in-the-dark stuff we have, and how we take so much of it "
"for granted. ",
"If I lived back in the Wild West days, instead of carrying a six-gun "
"in my holster, I'd carry a soldering iron. That way, if some "
"smart-aleck cowboy said something like \"Hey, look. He's carrying a "
"soldering iron!\" and started laughing, and everybody else started "
"laughing, I could just say, \"That's right, it's a soldering iron. The "
"soldering iron of justice.\" Then everybody would get real quiet and "
"ashamed, because they made fun of the soldering iron of justice, and I "
"could probably hit them up for a free drink. ",
"If there was a terrible storm outside, but somehow this dog lived "
"through the storm, and he showed up at your door when the storm was "
"finally over, I think a good name for him would be Carl. ",
"If they have moving sidewalks in the future, when you get on them, I "
"think you should have to assume sort of a walking shape so as not to "
"frighten the dogs. ",
"If trees could scream, would we be so cavalier about cutting them "
"down? We might, if they screamed all the time for no good reason. ",
"If you define cowardice as running away at the first sign of danger, "
"screaming and tripping and begging for mercy, then yes, Mister Brave "
"Man, I guess I am a coward. ",
"If you ever fall off the Sears Tower, just go real limp, because "
"maybe you'll look like a dummy and people will try to catch you "
"because, hey, free dummy. ",
"If you ever go temporarily insane, don't shoot somebody, like a lot "
"of people do. Instead, try to get some weeding done, because you'd "
"really be surprised. ",
"If you ever teach a yodeling class, the hardest thing is to keep the "
"students from just trying to yodel right off. You see, we build to "
"that. ",
"If you go parachuting, and your parachute doesn't open, and your "
"friends are all watching you fall, I think a funny gag would be to "
"pretend you were swimming. ",
"If you go to a party, and you want to be the popular one at the "
"party, do this: Wait until no one is looking, then kick a burning log "
"out of the fireplace onto the carpet. Then jump on top of it with your "
"body and yell, \"Log o' fire! Log o' fire!\" I've never done this, but "
"I think it'd work. ",
"If you had a school for professional fireworks people, I don't think "
"you could cover fuses in just one class. It's just too rich a "
"subject. ",
"If you saw two guys names Hambone and Flippy, which one would you "
"think liked dolphins the most? I'd say Flippy, wouldn't you? You'd be "
"wrong though. It's Hambone. ",
"If you want to be the most popular person in your class, whenever the "
"professor pauses in his lecture, just let out a big snort and say "
"\"How do you figger that!\" real loud. Then lean back and sort of "
"smirk. ",
"If you work on a lobster boat, sneaking up behind people and pinching "
"them is probably a joke that gets old real fast. ",
"If you're a circus clown, and you have a dog that you use in your "
"act, I don't think it's a good idea to also dress the dog up like a "
"clown, because people see that and they think, \"Forgive me, but "
"that's just too much.\" ",
"If you're a horse, and someone gets on you, and falls off, and then "
"gets right back on you, I think you should buck him off right away. ",
"If you're a young Mafia gangster out on your first date, I bet it's "
"really embarrassing if someone tries to kill you. ",
"If you're at a Thanksgiving dinner, but you don't like the stuffing "
"or the cranberry sauce or anything else, just pretend like your eating "
"it, but instead, put it all in your lap and form it into a big mushy "
"ball. Then, later, when you're out back having cigars with the boys, "
"let out a big fake cough and throw the ball to the ground. Then say, "
"\"Boy, these are good cigars!\" ",
"If you're ever shipwrecked on a tropical island and you don't know "
"how to speak the natives' language, just say \"Poppy-oomy.\" I bet it "
"means something. ",
"If you're ever stuck in some thick undergrowth, in your underwear, "
"don't stop and start thinking of what other words have Runder in them, "
"because that's probably the first sign of jungle madness. ",
"If you're in a boxing match, try not to let the other guy's glove "
"touch your lips, because you don't know where that glove has been. ",
"In some places it's known as a tornado. In others, a cyclone. And in "
"still others, the Idiot's Merry-go-round. But around here they'll "
"always be known as screw-boys. ",
"In weightlifting, I don't think sudden, uncontrolled urination should "
"automatically disqualify you. ",
"Instead of having \"answers\" on a math test, they should just call "
"them \"impressions,\" and if you got a different \"impression,\" so "
"what, can't we all be brothers? ",
"Instead of studying for finals, what about just going to the Bahamas "
"and catching some rays? Maybe you'll flunk, but you might have flunked "
"anyway; that's my point. ",
"Is there anything more beautiful than a beautiful, beautiful "
"flamingo, flying across in front of a beautiful sunset? And he's "
"carrying a beautiful rose in his beak, and also he's carrying a very "
"beautiful painting with his feet. And also, you're drunk. ",
"It makes me mad when I go to all the trouble of having Marta cook up "
"about a hundred drumsticks, then the guy at Marineland says, \"You "
"can't throw chicken to the dolphins. They eat fish.\" Sure they eat "
"fish, if that's all you give them. Man, wise up. ",
"It makes me mad when people say I turned and ran like a scared "
"rabbit. Maybe it was like an angry rabbit, who was running to go fight "
"in another fight, away from the first fight. ",
"It takes a big man to cry, but it takes a bigger man to laugh at that "
"man. ",
"It's amazing to me that one of the world's most feared diseases would "
"be carried by one of the world's smallest animals: the real tiny "
"dog. ",
"It's fascinating to think that all around us there's an invisible "
"world we can't even see. I'm speaking, of course, of the World of the "
"Invisible Scary Skeletons. ",
"It's not good to let any kid near a container that has a skull and "
"crossbones on it, because there might be a skeleton costume inside and "
"the kid could put it on and really scare you. ",
"It's too bad that whole families have to be torn apart by something "
"as simple as wild dogs. ",
"Just as irrigation is the lifeblood of the Southwest, lifeblood is "
"the soup of cannibals. ",
"Laugh, clown, laugh. This is what I tell myself whenever I dress up "
"like Bozo. ",
"Laurie got offended that I used the word \"puke.\" But to me, that's "
"what her dinner tasted like. ",
"Life, to me, is like a quiet forest pool, one that needs a direct hit "
"from a big rock half-buried in the ground. You pull and you pull, but "
"you can't get the rock out of the ground. So you give it a good kick, "
"but lose your balance and go skidding down the hill toward the "
"pool. Then out comes a big Hawaiian man who was screwing his wife "
"beside the pool because they thought it was real pretty. He tells you "
"to get out of there, but you start faking it, like you're talking "
"Hawaiian, and then he gets mad and chases you. ",
"Love can sweep you off your feet and carry you along in a way you've "
"never known before. But the ride always ends, and you end up feeling "
"lonely and bitter. Wait. It's not love I'm describing. I'm thinking of "
"a monorail. ",
"Marta says the interesting thing about fly fishing is that it's two "
"lives connected by a thin strand. Come on, Marta. Grow up. ",
"Marta was watching the football game with me when she said, \"You "
"know, most of these sports are based on the idea of one group "
"protecting its territory from invasion by another group.\" \"Yeah,\" I "
"said, trying not to laugh. Girls are funny. ",
"Most people don't realize that large pieces of coral, which have been "
"painted brown and attached to the skull by common wood screws, can "
"make a child look like a deer. ",
"Of all the tall tales, I think my favorite is the one about Eli "
"Whitney and the interchangeable parts. ",
"Once, when I was in Hawaii, on the island of Kauai, I met a "
"mysterious old stranger. He said he was about to die and wanted to "
"tell someone about the treasure. I said, \"Okay, as long as it's not a "
"long story. Some of us have a plane to catch, you know.\" He started "
"telling his story, about the treasure and his life and all, and I "
"thought: \"This story isn't too long.\" But then, he kept going, and I "
"started thinking, \"'Uh-oh, this story is getting long.\" But then the "
"story was over, and I said to myself: \"You know, that story wasn't "
"too long after all.\" I forgot what the story was about, but there was "
"a good movie on the plane. It was a little long, though. I didn't say "
"it was an interesting story. ",
"One question that's never been answered to my satisfaction by the "
"\"Playboy Advisor\" is \"What kind of stereo system works best in "
"hell?\" ",
"One thing kids like is to be tricked. For instance, I was going to "
"take my little nephew to Disneyland, but instead I drove him to an old "
"burned-out warehouse. \"Oh, no\", I said, \"Disneyland burned down.\" "
"He cried and cried, but I think that deep down, he thought it was a "
"pretty good joke. I started to drive over to the real Disneyland, but "
"it was getting pretty late. ",
"One thing that makes me believe in UFOs is, sometimes I lose "
"stuff. ",
"People think it would be fun to be a bird because you could fly. But "
"they forget the negative side, which is the preening. ",
"Perhaps, if I am very lucky, the feeble efforts of my lifetime will "
"someday be noticed, and maybe, in some small way, they will be "
"acknowledged as the greatest works of genius ever created by Man. ", 

"Probably to a shark, about the funniest thing there is a wounded "
"seal, trying to swim to shore, because where does he think he's " 
"going?! ",
"Some folks say it was a miracle. Saint Francis suddenly appeared and "
"knocked the next pitch clean over the fence. But I think it was just a "
"lucky swing. ",
"Sometimes I think the world has gone completely mad. And then I "
"think, \"Aw, who cares?\" And then I think, \"Hey, what's for "
"supper?\" ",
"Sometimes I wish Marta were more loyal to me. Like the other day. The "
"car parked next to ours had a real dirty windshield; so I wrote THIS "
"CAR LOOKS LIKE A FART in the dirt. Later I asked Marta if she thought "
"it was a childish thing to do. She said, \"Well, maybe,\" Man, whose "
"side is she on, anyway? ",
"Sometimes I wonder if I'm sexy enough. When I walk into a singles bar "
"with my \"fashionable\" shirt, \"fashionable\" slacks, and a big new "
"rubber manta-ray helmet. I can't help wondering: Do women want to talk "
"to me for myself, or do they just want to get a feel of that nice "
"rubber manta skin? ",
"Sometimes life seems like a dream, especially when I look down and "
"see that I forgot to put on my pants. ",
"Sometimes the beauty of the world is so overwhelming, I just want to "
"throw back my head and gargle. Just gargle and gargle, and I don't "
"care who hears me, because I am beautiful. ", 

"Sometimes when I feel like killing someone, I do a little trick to "
"calm myself down. I'll go over to the person's house and ring the "
"doorbell. When the person comes to the door, I'm gone, but you know "
"what I've left on the porch? A jack-o'-lantern with a knife in the "
"side of it's head with a note that says \"You.\" After that, I usually "
"feel a lot better, and no harm done. ",
"Sometimes, when I drive across the desert in the middle of the night, "
"with no other cars around, I start imagining: What if there were no "
"civilization out there? No cities, no factories, no people? And then I "
"think: No people or factories? Then who made this car? And this "
"highway? And I get so confused I have to stick my head out the window "
"into the driving rain unless there's lightning, because I could get "
"struck on the head by a bolt. ",
"The difference between a man and a boy is, a boy wants to grow up to "
"be a fireman, but a man wants to grow up to be a giant monster "
"fireman. ",
"The face of a child can say it all, especially the mouth part. ",
"The land that had nourished him and had borne him fruit now turned "
"against him and called him a fruit. Man, I hate land like that. ",
"The memories of my family outings are still a source of strength to "
"me. I remember we'd all pile into the car. I forget what kind it was "
"and drive and drive. I'm not sure where we'd go, but I think there "
"were some trees there. The smell of something was strong in the air as "
"we played whatever sport we played. I remember a bigger, older guy we "
"called Dad. We'd eat some stuff, or not, and then I think we went "
"home. I guess some things never leave you. ", 

"The next time I have meat and mashed potatoes, I think I'll put a "
"very large blob of potatoes on my plate with just a little piece of "
"meat. And if someone asks me why I didn't get more meat, I'll just "
"say, \"Oh, you mean this?\" and pull out a big piece of meat from "
"inside the blob of potatoes, where I've hidden it. Good magic trick, "
"huh? ",
"The old pool shooter had won many a game in his life. But now it was "
"time to hang up the cue. When he did, all the other cues came crashing "
"to the floor. \"Sorry,\" he said with a smile. ",
"The prince decided he would learn anger. So he gathered his subjects "
"together outside his balcony. \"Who would teach me anger?\" he "
"said. \"Fuck you!\" somebody yelled. \"Okay, how about algebra?\" said "
"the prince. ",
"The sound of fresh rain run-off splashing from the roof reminded me "
"of the sound of urine splashing into a filthy Texaco latrine. ",
"The whole town laughed at my great-grandfather, just because he "
"worked hard and saved his money. True, working at the hardware store "
"didn't pay much, but he felt it was better than what everybody else "
"did, which was go up to the volcano and collect the gold nuggets it "
"shot out every day. It turned out he was right. After forty years, the "
"volcano petered out. Everybody left town, and the hardware store went "
"broke. Finally he decided to collect gold nuggets too, but there "
"weren't many left by then. Plus, he broke his leg and the doctor's "
"bills were real high. ",
"To me, boxing is like a ballet, except there's no music, no "
"choreography, and the dancers hit each other. ",
"To me, clowns aren't funny. In fact, they're kinda scary. I've "
"wondered where this started, and I think it goes back to the time I "
"went to the circus and a clown killed my dad. ",
"To me, truth is not some vague, foggy notion. Truth is real. And, at "
"the same time, unreal. Fiction and fact and everything in between, "
"plus some things I can't remember, all rolled into one big \"thing.\" "
"This is a truth, to me. ",
"Today I accidentally stepped on a snail on the sidewalk in front of "
"our house. And I thought, I too am like that snail. I build a "
"defensive wall around myself, a \"shell\" if you will. But my shell "
"isn't made out of a hard, protective substance. Mine is made out of "
"tinfoil and paper bags. ",
"Tonight, when we were eating dinner, Marta said something that really "
"knocked me for a loop. She said, \"I love carrots.\" \"Good,\" I said "
"as I gritted my teeth real hard. \"Then maybe you and carrots would "
"like to go into the bedroom and have sex!\" They didn't, but maybe "
"they will sometime, and I can watch. ",
"Too bad Lassie didn't know how to ice skate, because then if she was "
"in Holland on vacation in winter and someone said \"Lassie, go skate "
"for help,\" she could do it. ",
"Too bad there's not such a thing as a golden skunk, because you'd "
"probably be proud to be sprayed by one. ",
"Too bad when I was a kid there wasn't a guy in our class that "
"everybody called the \"Cricket Boy\", because I would have liked to "
"stand up in class and tell everybody, \"You can make fun of the "
"Cricket Boy if you want to, but to me he's just like everybody else.\" "
"Then everybody would leave the Cricket Boy alone, and I'd invite him "
"over to spend the night at my house, but after about five minutes of "
"that loud chirping I'd have to kick him out. Maybe later we could get "
"up a petition to get the Cricket Family run out of town. Bye, Cricket "
"Boy. ",
"Too bad you can't just grab a tree by the very tiptop and bend it "
"clear over the ground and then let her fly, because I bet you'd be "
"amazed at all the stuff that comes flying out. ",
"We tend to scoff at the beliefs of the ancients. But we can't scoff "
"at them personally, to their faces, and this is what annoys me. ",
"We used to laugh at Grandpa when he'd head off to go fishing. But we "
"wouldn't be laughing that evening, when he'd come back with some whore "
"he picked up in town. ",
"What is it that makes a complete stranger dive into an icy river to "
"save a solid gold baby? Maybe we'll never know. ",
"When I heard that trees grow a new \"ring\" for each year they live, "
"I thought we humans are kind of like that: we grow a new layer of skin "
"each year, and after many years we are thick and unwieldy from all of "
"our skin layers. ",
"When I think back on all the blessings I have been given in my life, "
"I can't think of a single one, unless you count that rattlesnake that "
"granted me all those wishes. ",
"When the age of the Vikings came to a close, they must have sensed "
"it. Probably, they gathered together one evening, slapped each other "
"on the back and said, \"Hey, good job.\" ",
"When the chairman introduced the guest speaker as a former illegal "
"alien, I got up from my chair and yelled, \"What's the matter, no jobs "
"on Mars?\" When no one laughed, I was real embarrassed. I don't think "
"people should make you feel that way. ", 

"When you go for a job interview, I think a good thing to ask is if "
"they ever press charges. ",
"When you're going up the stairs and you take a step, kick the other "
"leg up high behind you to keep people from following too close. ",
"Whenever I hear the sparrow chirping, watch the woodpecker chirp, "
"catch a chirping trout, or listen to the sad howl of the chirp rat, I "
"think: Oh boy! I'm going insane again. ",
"Whenever I see an old lady slip and fall on a wet sidewalk, my first "
"instinct is to laugh. But then I think, what if I was an ant, and she "
"fell on me. Then it wouldn't seem quite so funny. ",
"Whether they ever find life there or not, I think Jupiter should be "
"considered an enemy planet. ",
"You know what would make a good story? Something about a clown who "
"makes people happy, but inside he's real sad. Also, he has severe "
"diarrhea. ",
"I think, therefore I wish I wasn't. ",
"I think, therefore I think I am. ",
"Pouring cheesewiz on somebody should be considered a biochemical attack. "});

array register_module()
{
  return ({ MODULE_PARSER, 
	    "Deep thought module",
	    "Adds an extra tag, 'dthought'.", ({}), 1
	    });
}


string deep_thought(string tag, mapping m) 
{ 
  return thoughts[random(sizeof(thoughts))]; 
}

string info() { return deep_thought("", ([])); }

mapping query_tag_callers() { return (["dthought":deep_thought,]); }

mapping query_container_callers() { return ([]); }


