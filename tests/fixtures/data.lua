-- Fixture data pack in the docs/ARCHITECTURE.md §4 string format.
-- Default test character: Warrior 62, Alliance Human, Arms, Blacksmithing 300, in Zangarmarsh.
return function(D)
  D.meta = { version = "fixture", built = "2026-09-19", dbVersion = "test", items = 0, quests = 0, phases = 5 }

  D.zones[3521] = "Zangarmarsh"
  D.zones[3483] = "Hellfire Peninsula"
  D.zones[3519] = "Terokkar Forest"
  D.zones[3518] = "Nagrand"
  D.zones[3905] = "Coilfang Reservoir"

  D.dungeons[547] = { name = "The Slave Pens", min = 55, max = 65, zone = 3521, heroic = true,
    bosses = { 17941, 17991, 17942 }, t = { 8, 15, 25 }, qz = { 3905 } }
  D.dungeons[543] = { name = "Hellfire Ramparts", min = 55, max = 62, zone = 3483, heroic = true,
    bosses = { 17306, 17308 }, t = { 10, 20 }, qz = { 3535 } }

  D.bosses[17941] = "547;0;0"
  D.bosses[17991] = "547;1;0"
  D.bosses[17942] = "547;2;0"
  D.bosses[19895] = "547;1;1"
  D.bosses[17306] = "543;0;0"
  D.bosses[17308] = "543;1;0"

  D.npcs[17941] = "Mennu the Betrayer;64;1;547;0"
  D.npcs[17991] = "Rokmar the Crackler;64;1;547;0"
  D.npcs[17942] = "Quagmirran;64;1;547;0"
  D.npcs[19895] = "Rokmar the Crackler;72;1;547;0"
  D.npcs[17306] = "Watchkeeper Gargolmar;61;1;543;0"
  D.npcs[17308] = "Omor the Unscarred;62;1;543;0"
  D.npcs[18678] = "Fulgorge;64;2;530;180"
  D.npcs[20000] = "Durn the Hungerer;65;1;530;0"
  D.npcs[21000] = "Ambassador Jerrikar;65;4;530;120"
  D.npcs[23000] = "Overleveled Mob;70;0;530;0"

  D.objects[183000] = "Coilfang Chest;547"

  -- quests: title;minLevel;questLevel;races;classes;zone;type;prev;next;excl;choice;fixed
  D.quests[9876] = "Drain Schematics;60;63;0;0;3521;0;0;9738;0;;"
  D.quests[9738] = "Lost in Action;62;65;0;0;3905;81;9876;0;0;30701,30702;"
  D.quests[10000] = "Chain A1;58;60;0;0;3521;0;0;10001;0;;"
  D.quests[10001] = "Chain A2;58;61;0;0;3521;0;10000;10002;0;;"
  D.quests[10002] = "Chain A3;58;62;A;0;3521;0;10001;0;0;30001,30002;"
  D.quests[10010] = "Horde Only;58;60;H;0;3483;0;0;0;0;30003;"
  D.quests[10011] = "Priest Only;58;60;0;16;3483;0;0;0;0;30004;"
  D.quests[10012] = "Group Quest;60;62;0;0;3483;1;0;0;0;30005;"
  D.quests[10013] = "High Level Quest;66;68;0;0;3518;0;0;0;0;30006;"
  D.quests[10014] = "Raid Quest;60;60;0;0;3518;62;0;0;0;30007;"
  D.quests[10015] = "Done Quest;58;60;0;0;3521;0;0;0;0;30008;"
  D.quests[10016] = "Other Zone Quest;58;60;0;0;3483;0;0;0;0;30009;"
  D.quests[10017] = "Fixed Reward Quest;58;60;0;0;3521;0;0;0;0;;30030"

  -- items: name;inv;cls;sub;q;ilvl;req;classmask;flags;stats;sockets;sbonus;phase
  local items = {
    -- HEAD
    [30001] = { "Chain Helm;1;4;3;3;100;60;0;0;STA:20,STR:15,CRIT:14;;0;1", "Q10002" },
    [30002] = { "Cloth Hood;1;4;1;3;100;60;0;0;INT:20,SP:25;;0;1", "Q10002" },
    [30003] = { "Horde Helm;1;4;3;3;100;58;0;0;STA:30,STR:30;;0;1", "Q10010" },
    [30004] = { "Priest Helm;1;4;1;3;100;58;0;0;INT:30;;0;1", "Q10011" },
    [30005] = { "Group Helm;1;4;4;3;105;60;0;0;STA:25,STR:25;;0;1", "Q10012" },
    [30006] = { "High Level Helm;1;4;4;3;115;66;0;0;STA:40,STR:40;;0;1", "Q10013" },
    [30007] = { "Raid Helm;1;4;4;3;120;60;0;0;STA:50,STR:50;;0;1", "Q10014" },
    [30008] = { "Done Helm;1;4;4;3;100;58;0;0;STA:22,STR:22;;0;1", "Q10015" },
    [30009] = { "Travel Helm;1;4;4;3;100;58;0;0;STA:18,STR:18;;0;1", "Q10016" },
    [30010] = { "Boss Helm;1;4;4;3;110;62;0;0;STA:28,STR:26,HIT:10;;0;1", "B17991:20" },
    [30011] = { "Lottery Helm;1;4;4;3;110;62;0;0;STA:30,STR:30;;0;1", "B17942:5" },
    [30012] = { "Heroic Helm;1;4;4;4;115;70;0;32;STA:40,STR:40;;0;1", "B19895:20" },
    [30013] = { "Rare Helm;1;4;4;3;105;60;0;0;STA:24,STR:24;;0;1", "R18678:9" },
    [30014] = { "Named Helm;1;4;4;3;105;60;0;0;STA:20,STR:24;;0;1", "N20000:3" },
    [30015] = { "Trash Helm;1;4;4;3;105;60;0;0;STA:20,STR:20;;0;1", "T547:1.5" },
    [30016] = { "Chest Helm;1;4;4;3;105;60;0;0;STA:21,STR:21;;0;1", "G183000:16" },
    [30017] = { "Vendor Helm;1;4;4;2;100;58;0;0;STA:19,STR:19;;0;1", "V125000:0" },
    [30018] = { "Rep Helm;1;4;4;3;110;60;0;0;STA:30,STR:32;;0;1", "V150000:F942-6" },
    [30019] = { "Crafted Helm;1;4;4;3;105;60;0;2;STA:26,STR:26;;0;1", "K164:340" },
    [30020] = { "Ext Helm;1;4;4;4;115;70;0;0;STA:45,STR:45;;0;1", "V0:E" },
    [30040] = { "Honor Helm;1;4;4;4;115;70;0;0;STA:46,STR:46;;0;1", "V0:H" },
    [30041] = { "Arena Helm;1;4;4;4;136;70;0;0;STA:60,STR:60;;0;1", "V0:A" },
    [30042] = { "Raid Helm Sourceless;1;4;4;4;141;70;0;0;STA:70,STR:70;;0;1", "" },
    [30021] = { "World Helm;1;4;4;3;100;58;0;2;STA:23,STR:23;;0;1", "W0.5" },
    [30022] = { "Socket Helm;1;4;4;3;110;62;0;0;STA:20,STR:20;RY;2859;1", "B17941:25" },
    [30023] = { "Special Helm;1;4;4;3;110;62;0;16;STA:20,STR:20;;0;1", "B17941:25" },
    [30024] = { "Set Helm;1;4;4;3;110;62;0;8;STA:20,STR:20;;0;1", "B17941:25" },
    [30025] = { "Phase 5 Helm;1;4;4;4;128;70;0;0;STA:50,STR:50;;0;5", "V0:E" },
    [30026] = { "Class Helm;1;4;1;3;100;60;16;0;INT:30;;0;1", "V100:0" },
    [30027] = { "Too High Mob Helm;1;4;4;3;115;62;0;0;STA:40,STR:40;;0;1", "N23000:5" },
    [30028] = { "Hidden Helm;1;4;4;3;110;62;0;0;STA:29,STR:29;;0;1", "B17941:30" },
    [30029] = { "Leather Helm;1;4;2;3;110;62;0;0;STA:27,STR:27,AGI:10;;0;1", "B17941:30" },
    [30030] = { "Fixed Reward Helm;1;4;4;3;100;58;0;0;STA:17,STR:17;;0;1", "Q10017" },
    [30031] = { "Multi Source Helm;1;4;4;3;110;62;0;0;STA:25,STR:28;;0;1", "B17942:5|Q10016|V200000:0" },
    [30032] = { "Rare Elite Helm;1;4;4;3;105;60;0;0;STA:22,STR:25;;0;1", "R21000:12" },
    [30035] = { "Low Trash Helm;1;4;3;2;70;45;0;0;STA:8,STR:8;;0;1", "T547:2" },
    [30033] = { "Alliance Helm;1;4;4;3;110;62;0;64;STA:24,STR:26;;0;1", "V1000:0" },
    [30034] = { "Horde Helm Item;1;4;4;3;110;62;0;128;STA:24,STR:26;;0;1", "V1000:0" },
    [30100] = { "Old Helm;1;4;3;2;80;50;0;0;STA:10,STR:10;;0;1", "V1000:0" },
    -- NECK / BACK / CHEST
    [30701] = { "Cloak of Action;16;4;0;3;110;62;0;0;STA:15,STR:15;;0;1", "Q9738" },
    [30702] = { "Necklace of Action;2;4;0;3;110;62;0;0;STA:15,STR:15;;0;1", "Q9738" },
    [30601] = { "Chest Plate;5;4;4;3;110;62;0;0;STA:35,STR:35;;0;1", "B17942:20" },
    [30602] = { "Robe;20;4;1;3;110;62;0;0;INT:35,SP:40;;0;1", "B17942:20" },
    -- FINGER / TRINKET
    [30201] = { "Ring A;11;4;0;3;100;60;0;0;STR:10,STA:10;;0;1", "V1000:0" },
    [30202] = { "Ring B;11;4;0;3;100;60;0;0;STR:5,STA:5;;0;1", "V1000:0" },
    [30203] = { "Ring Upgrade;11;4;0;3;110;62;0;0;STR:20,STA:20;;0;1", "B17991:30" },
    [30204] = { "Unique Ring;11;4;0;3;110;62;0;1;STR:22,STA:22;;0;1", "B17991:30" },
    [30301] = { "Trinket Old;12;4;0;2;80;50;0;0;STA:10;;0;1", "V1000:0" },
    [30302] = { "Trinket New;12;4;0;3;110;62;0;0;STA:25,STR:20;;0;1", "B17942:20" },
    -- WEAPONS / OFFHAND
    [30401] = { "Old 1H Sword;13;2;7;2;80;50;0;0;DPS:40,SPEED:2.6,STR:5;;0;1", "V1000:0" },
    [30402] = { "Old OH Sword;22;2;7;2;80;50;0;0;DPS:38,SPEED:1.8;;0;1", "V1000:0" },
    [30403] = { "Big 2H;17;2;8;3;110;62;0;0;DPS:80,SPEED:3.5,STR:30,STA:25;;0;1", "B17991:20" },
    [30404] = { "New 1H;13;2;7;3;110;62;0;0;DPS:60,SPEED:2.6,STR:15;;0;1", "B17941:20" },
    [30405] = { "Shield;14;4;6;3;110;62;0;0;STA:30,BLOCKV:50,ARMOR:2000;;0;1", "B17942:20" },
    [30406] = { "Held Orb;23;4;0;3;110;62;0;0;INT:20,SP:20;;0;1", "V1000:0" },
    [30407] = { "Old 2H;17;2;8;2;80;50;0;0;DPS:60,SPEED:3.4,STR:15;;0;1", "V1000:0" },
    [30408] = { "Dagger;13;2;15;3;110;62;0;0;DPS:55,SPEED:1.5,AGI:15;;0;1", "B17941:20" },
    -- RANGED
    [30501] = { "Bow;15;2;2;3;110;62;0;0;RDPS:70,SPEED:2.8,AGI:10;;0;1", "B17941:20" },
    [30502] = { "Wand;26;2;19;3;110;62;0;0;DPS:100,SPEED:1.5,SP:10;;0;1", "B17941:20" },
    [30503] = { "Old Gun;26;2;3;2;80;50;0;0;RDPS:40,SPEED:2.5;;0;1", "V1000:0" },
    [30504] = { "Idol;28;4;8;3;100;60;1024;0;;;0;1", "V1000:0" },
  }
  local n = 0
  for id, rec in pairs(items) do
    D.items[id] = rec[1]
    D.src[id] = rec[2]
    n = n + 1
  end
  D.meta.items = n
  D.meta.quests = 13
  D.specials[30023] = "AP:40"
end
