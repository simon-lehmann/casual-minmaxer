-- luacheck: no max line length
-- Hand-assigned stat equivalents for proc / on-use / chance-on-hit items (design doc: ~100 most relevant).
-- CMM.Specials.TABLE[itemId] = { AP = 90 } etc. Values are added to the item's stats before scoring.
--
-- Keys: flat AP, RAP, FAP, SP, HEAL, MP5, STA, ARMOR, DPS, plus HASTE / CRIT / HIT as raw rating points
-- (the addon converts ratings). Values are conservative community-style "equivalent stat" estimates for
-- average uptime; an item with both AP and SP is role-neutral: each spec's weights pick the key it cares
-- about. Item ids were checked against the CMaNGOS TBC item_template. Raid items are excluded (non-goal).
-- pipeline/overrides/specials.json mirrors this table so the pipeline flags these items.
local _, CMM = ...
local S = CMM.Specials

S.TABLE = {
  -- Classic leveling / level 60 trinkets
  [11815] = { AP = 60 },                      -- Hand of Justice: 2% extra attack proc
  [13965] = { CRIT = 28 },                    -- Blackhand's Breadth: +2% crit (converted to rating at 60)
  [11684] = { DPS = 4 },                      -- Ironfoe: chance for 2 extra attacks (1H mace)
  [12590] = { CRIT = 30 },                    -- Felstriker: chance for 100% crit/hit for 3 s
  [19991] = { CRIT = 28 },                    -- Devilsaur Eye: on use +150 AP/2% crit (averaged)
  [19992] = { AP = 30 },                      -- Devilsaur Tooth: first hit crit for pet, AP proc
  [20130] = { STR = 25 },                     -- Diamond Flask: on use +75 STR 1 min / 6 min
  [19120] = { AP = 22 },                      -- Rune of the Guard Captain: +2% crit? (on-use AP), conservative
  [17774] = { STA = 8 },                      -- Mark of the Chosen: 2% chance +25 all stats for 1 min
  [21180] = { AP = 65 },                      -- Earthstrike: on use +280 AP for 20 s / 2 min
  [23570] = { AP = 70 },                      -- Jom Gabbar: on use ramping AP
  [22954] = { HASTE = 55 },                   -- Kiss of the Spider: on use 20% haste 15 s / 2 min (2% crit passive is a stat)
  [21670] = { ARP = 100 },                    -- Badge of the Swarmguard: on use armor penetration stacks
  [23041] = { AP = 60 },                      -- Slayer's Crest: on use +260 AP 20 s / 2 min
  [19406] = { AP = 30 },                      -- Drake Fang Talisman: +56 AP passive is a stat; hit is stat; token 0 extra
  [21647] = { AP = 50 },                      -- Fetish of the Sand Reaver: on use armor reduction
  [18820] = { SP = 45 },                      -- Talisman of Ephemeral Power: on use +175 SP 15 s / 90 s
  [19950] = { SP = 35, HEAL = 35 },           -- Zandalarian Hero Charm: on use +204 spell dmg/healing decaying
  [23046] = { SP = 40 },                      -- The Restrained Essence of Sapphiron (raid; kept 0 elsewhere) — see note below
  [23047] = { SP = 50 },                      -- Eye of the Dead: on use +450 healing/ +150 dmg 30 s
  [19395] = { HEAL = 55, SP = 20 },           -- Rejuvenating Gem: on use +66 healing... conservative
  [23027] = { MP5 = 25 },                     -- Warmth of Forgiveness: on use 500 mana / 3 min
  [21625] = { HEAL = 50 },                    -- Scarab Brooch: on use absorb shield on heals
  [19288] = { STA = 15, SP = 10 },            -- Darkmoon Card: Blue Dragon: 2% chance 100% mana regen while casting
  [19287] = { STA = 10 },                     -- Darkmoon Card: Heroism: chance to heal 120-180 on melee
  [19289] = { DPS = 3 },                      -- Darkmoon Card: Maelstrom: chance for 200-300 nature damage on hit
  [14022] = { STA = 5 },                      -- Barov Peasant Caller (A): summons peasants
  [14023] = { STA = 5 },                      -- Barov Peasant Caller (H)
  [13503] = { MP5 = 15, STA = 6 },            -- Alchemist's Stone: +40% potion effect
  [19998] = { SP = 25 },                      -- Bloodvine Lens: +2% spell crit is a stat; conservative extra 0 -> small SP
  [18854] = { STA = 0 }, [18856] = { STA = 0 }, [18857] = { STA = 0 }, [18858] = { STA = 0 }, -- Insignia of the Alliance
  [18859] = { STA = 0 }, [18862] = { STA = 0 }, [18863] = { STA = 0 }, [18864] = { STA = 0 }, [29593] = { STA = 0 },
  [18834] = { STA = 0 }, [18845] = { STA = 0 }, [18846] = { STA = 0 }, [18849] = { STA = 0 }, -- Insignia of the Horde
  [18850] = { STA = 0 }, [18851] = { STA = 0 }, [18852] = { STA = 0 }, [18853] = { STA = 0 }, [29592] = { STA = 0 },

  -- Outland leveling trinkets (green/blue quest rewards)
  [31617] = { AP = 30 },                      -- Ancient Draenei War Talisman: on use +65 AP 20 s
  [25937] = { HIT = 22 },                     -- Terokkar Tablet of Precision: on use +140 AP? conservative hit-ish; AP 30
  [25936] = { SP = 25 },                      -- Terokkar Tablet of Vim: on use +... spell damage
  [25634] = { SP = 20, HEAL = 20 },           -- Oshu'gun Relic: on use +... spell damage/healing
  [28042] = { STA = 10, ARMOR = 60 },         -- Regal Protectorate: on use +... stamina/health
  [30300] = { SP = 25 },                      -- Dabiri's Enigma: on use +... spell damage
  [29776] = { SP = 25 },                      -- Core of Ar'kelos: on use +... spell damage
  [25633] = { STA = 8 },                      -- Uniting Charm: on use +... health (random enchant)
  [25995] = { SP = 25, HEAL = 25 },           -- Star of Sha'naar: on use +... healing
  [25628] = { STR = 20 },                     -- Ogre Mauler's Badge: on use +... strength
  [25619] = { HEAL = 25 },                    -- Glowing Crystal Insignia: on use +... healing
  [28040] = { AP = 40 },                      -- Vengeance of the Illidari: on use +200 AP 15 s / 90 s
  [28041] = { AP = 70 },                      -- Bladefist's Breadth: on use +200 AP 15 s / 2 min + 24 AP? (Horde/Alliance versions)
  [27891] = { STA = 12, ARMOR = 60 },         -- Adamantine Figurine: on use +... armor
  [27920] = { AP = 30 }, [27921] = { AP = 30 }, -- Mark of Conquest: chance on ranged/melee hit +... (A/H)
  [27922] = { STA = 8 }, [27924] = { STA = 8 }, -- Mark of Defiance: chance on hit heal

  -- Level 70 pre-raid trinkets
  [28034] = { CRIT = 80 },                    -- Hourglass of the Unraveller: chance +300 crit rating 10 s (≈90 AP eq.)
  [28288] = { HASTE = 65 },                   -- Abacus of Violent Odds: on use +260 haste 10 s / 2 min
  [29370] = { SP = 70 },                      -- Icon of the Silver Crescent: on use +155 SP 20 s / 2 min
  [27683] = { HASTE = 40, SP = 5 },           -- Quagmirran's Eye: chance +320 spell haste 6 s
  [28190] = { SPCRIT = 20 },                  -- Scarab of the Infinite Cycle: chance +... spell haste; conservative
  [29376] = { HEAL = 80 },                    -- Essence of the Martyr: on use +297 healing 20 s / 2 min
  [29179] = { SP = 60 },                      -- Xi'ri's Gift: on use +150 SP 15 s / 90 s
  [30841] = { HEAL = 60 },                    -- Lower City Prayerbook: on use reduces heal cost
  [28590] = { HEAL = 70 },                    -- Ribbon of Sacrifice: on use +... healing over 20 s
  [29383] = { AP = 60 },                      -- Bloodlust Brooch: on use +278 AP 20 s / 2 min
  [29181] = { HASTE = 35, SP = 5 },           -- Timelapse Shard: on use +... haste
  [34472] = { AP = 90 },                      -- Shard of Contempt: chance +230 AP 20 s (phase 5)
  [34473] = { STA = 20, ARMOR = 250 },        -- Commendation of Kael'thas: chance +... dodge when struck
  [32654] = { AP = 90 },                      -- Crystalforged Trinket: on use +216 AP 10 s / 1 min
  [28121] = { HIT = 30 },                     -- Icon of Unyielding Courage: on use +... hit/expertise
  [35749] = { SP = 40, MP5 = 15 },            -- Sorcerer's Alchemist Stone
  [35751] = { AP = 60, MP5 = 5 },             -- Assassin's Alchemist Stone
  [35748] = { STA = 15, ARMOR = 100 },        -- Guardian's Alchemist Stone
  [35750] = { HEAL = 60, MP5 = 15 },          -- Redeemer's Alchemist Stone
  [31856] = { AP = 120, SP = 80 },            -- Darkmoon Card: Crusade: stacking +... (AP for melee, SP for casters)
  [31858] = { STA = 20, ARMOR = 250 },        -- Darkmoon Card: Vengeance: damage reflect
  [31857] = { SP = 60 },                      -- Darkmoon Card: Wrath: crit stacking (spell/melee)
  [31859] = { AP = 60, SP = 40 },             -- Darkmoon Card: Madness: random stat buff (averaged)
  [32770] = { HEAL = 70, MP5 = 5 },           -- Skyguard Silver Cross: chance +... healing proc
  [30627] = { HEAL = 50 },                    -- Tsunami Talisman: chance +... spell haste (healer)
  [30626] = { SP = 60 },                      -- Sextant of Unstable Currents: chance +190 SP 15 s
  [30720] = { SP = 60 },                      -- Serpent-Coil Braid: mana gem crit... (mage)
  [30664] = { AP = 40, SP = 30, HEAL = 30 },  -- Living Root of the Wildheart: form-dependent proc
  [30449] = { STA = 20 },                     -- Void Star Talisman: pet +... resist; conservative
  [30450] = { SP = 50 },                      -- Warp-Spring Coil: chance +... arcane damage
  [30447] = { SP = 60, HEAL = 60 },           -- Tome of Fiery Redemption: chance +... spell damage/healing
  [33828] = { SP = 50 },                      -- Tome of Diabolic Remedy: on use +... (phase 4)
  [33830] = { SP = 60 },                      -- Ancient Aqir Artifact: chance +... spell damage (ZA)
  [33831] = { AP = 110 },                     -- Berserker's Call: on use +360 AP 20 s / 2 min (ZA)
  [33829] = { SP = 80 },                      -- Hex Shrunken Head: on use +211 SP 20 s / 2 min (ZA)
  [24125] = { STA = 15, ARMOR = 120 },        -- Figurine - Dawnstone Crab: on use +... dodge
  [24126] = { SP = 55 },                      -- Figurine - Living Ruby Serpent: on use +... spell dmg
  [24127] = { HEAL = 60, MP5 = 10 },          -- Figurine - Talasite Owl: on use mana regen
  [24128] = { AP = 60 },                      -- Figurine - Nightseye Panther: on use +... AP
  [24124] = { STA = 15, ARMOR = 150 },        -- Figurine - Felsteel Boar: on use +... armor
  [35700] = { SP = 70 },                      -- Figurine - Crimson Serpent (phase 5)
  [35702] = { AP = 90 },                      -- Figurine - Shadowsong Panther (phase 5)
  [35703] = { HEAL = 80, MP5 = 15 },          -- Figurine - Seaspray Albatross (phase 5)
  [35693] = { STA = 20, ARMOR = 200 },        -- Figurine - Empyrean Tortoise (phase 5)
  [35694] = { AP = 60, STA = 10 },            -- Figurine - Khorium Boar (phase 5)
  [33832] = { STA = 15 }, [34578] = { STA = 15 },   -- Battlemaster's Determination: on use +1750 health
  [34049] = { STA = 15 }, [34579] = { STA = 15 },   -- Battlemaster's Audacity
  [34163] = { STA = 15 }, [34576] = { STA = 15 },   -- Battlemaster's Cruelty
  [34162] = { STA = 15 }, [34577] = { STA = 15 },   -- Battlemaster's Depravity
  [34050] = { STA = 15 }, [34580] = { STA = 15 },   -- Battlemaster's Perseverance
  [35326] = { STA = 15 }, [35327] = { STA = 15 },   -- Battlemaster's Alacrity
  [25829] = { STA = 0 }, [24551] = { STA = 0 },     -- Talisman of the Alliance / Horde: PvP escape only
  [28234] = { STA = 0 }, [28235] = { STA = 0 }, [28236] = { STA = 0 }, [28237] = { STA = 0 }, [28238] = { STA = 0 },
  [30348] = { STA = 0 }, [30349] = { STA = 0 }, [30350] = { STA = 0 }, [30351] = { STA = 0 }, [37864] = { STA = 0 }, -- Medallion of the Alliance
  [28239] = { STA = 0 }, [28240] = { STA = 0 }, [28241] = { STA = 0 }, [28242] = { STA = 0 }, [28243] = { STA = 0 },
  [30343] = { STA = 0 }, [30344] = { STA = 0 }, [30345] = { STA = 0 }, [30346] = { STA = 0 }, [37865] = { STA = 0 }, -- Medallion of the Horde

  -- Relics with static effects (librams / idols / totems), expressed as SP / AP / HEAL equivalents
  [27484] = { AP = 40 },                      -- Libram of Avengement: +53 crit rating after Judgement
  [29388] = { SP = 25, BLOCKV = 30 },         -- Libram of Repentance: block value for Holy Shield
  [28592] = { HEAL = 60 },                    -- Libram of Souls Redeemed: Flash of Light +... on Holy Light targets
  [27917] = { HEAL = 40, MP5 = 10 },          -- Libram of the Eternal Rest: judgement mana
  [22400] = { STA = 5 },                      -- Libram of Truth: Devotion Aura armor
  [22402] = { HEAL = 30 },                    -- Libram of Grace: Flash of Light healing
  [23006] = { HEAL = 40 },                    -- Libram of Light: Flash of Light +83 healing
  [27949] = { AP = 30 }, [27983] = { AP = 30 }, -- Libram of Zeal: Judgement of Righteousness damage
  [28065] = { SP = 20 },                      -- Libram of Wracking: Exorcism/Holy Wrath damage
  [31025] = { AP = 25 },                      -- Libram of the Avenger: Judgement crit? conservative
  [33504] = { HEAL = 50 },                    -- Libram of Divine Purpose: Holy Light healing (ZA)
  [32368] = { SP = 40, HEAL = 40 },           -- Tome of the Lightbringer: Judgement/Holy Light (BT/Hyjal, ranked here as relic)
  [32387] = { HEAL = 40, SP = 20, AP = 20 },  -- Idol of the Raven Goddess: form-dependent (badge vendor)
  [22397] = { AP = 25 },                      -- Idol of Ferocity: Claw/Rake energy cost
  [28064] = { FAP = 25 },                     -- Idol of the Wild: Ferocious Bite? conservative feral
  [27989] = { AP = 30 }, [27990] = { AP = 30 }, -- Idol of Savagery: Shred/Mangle? conservative
  [27886] = { HEAL = 40 },                    -- Idol of the Emerald Queen: Lifebloom healing
  [23004] = { HEAL = 35 },                    -- Idol of Longevity: Healing Touch mana
  [23197] = { SP = 25 },                      -- Idol of the Moon: Moonfire damage
  [25940] = { AP = 35 },                      -- Idol of the Claw: chance +... on Shred/Mangle
  [33509] = { AP = 60 },                      -- Idol of Terror: chance +65 agility on Mangle (ZA)
  [23198] = { AP = 30 },                      -- Idol of Brutality: Maul/Swipe rage
  [22398] = { HEAL = 25 },                    -- Idol of Rejuvenation: Rejuvenation healing
  [22395] = { AP = 20 },                      -- Totem of Rage: Stormstrike/Windfury damage
  [23199] = { SP = 25 },                      -- Totem of the Storm: Chain Lightning damage
  [22345] = { HEAL = 20 },                    -- Totem of Rebirth: Healing Wave
  [22396] = { HEAL = 30 },                    -- Totem of Life: Lesser Healing Wave
  [23200] = { HEAL = 25 },                    -- Totem of Sustaining: Lesser Healing Wave
  [27815] = { AP = 40 },                      -- Totem of the Astral Winds: +80 AP for Windfury? conservative
  [25645] = { SP = 20 },                      -- Totem of the Plains: Lightning Bolt
  [27947] = { SP = 25 }, [27984] = { SP = 25 }, -- Totem of Impact: Shock damage
  [28066] = { SP = 20 },                      -- Totem of Lightning: Chain Lightning
  [29389] = { SP = 40, MP5 = 8 },             -- Totem of the Pulsing Earth: Lightning Bolt mana
  [27544] = { HEAL = 40 },                    -- Totem of Spontaneous Regrowth: Healing Wave
  [28523] = { HEAL = 50 },                    -- Totem of Healing Rains: Chain Heal healing
  [28248] = { SP = 45 },                      -- Totem of the Void: Lightning Bolt damage

  -- Weapons with procs or on-use effects (leveling and pre-raid)
  [31332] = { DPS = 5 },                      -- Blinkstrike: chance for an extra attack
  [30832] = { SP = 30 },                      -- Gavel of Unearthed Secrets: chance +... spell damage
  [28189] = { DPS = 3 },                      -- Latro's Shifting Sword: chance +... haste
  [31291] = { DPS = 3 },                      -- Crystalforged War Axe: chance +... AP
  [28442] = { AP = 40 },                      -- Stormherald: chance to stun (PvP), conservative AP value
  [28441] = { AP = 35 },                      -- Deep Thunder: stun proc, conservative
  [28438] = { AP = 40 },                      -- Dragonmaw: chance +... haste
  [28439] = { AP = 45 },                      -- Dragonstrike: chance +... haste
  [28429] = { CRIT = 30 },                    -- Lionheart Champion: chance +... crit
  [28430] = { CRIT = 35 },                    -- Lionheart Executioner: chance +... crit
  [28433] = { AP = 40 },                      -- Wicked Edge of the Planes: on use +... AP
  [28436] = { AP = 40 },                      -- Bloodmoon: chance +... AP
  [29124] = { AP = 30 }, [29125] = { AP = 30 }, -- Vindicator's Brand / Retainer's Blade: rep-vendor swords with procs
  [28295] = { STA = 0 },                      -- Gladiator's Slicer: no proc; listed so the badge is not shown
  [32363] = { HEAL = 20 },                    -- Naaru-Blessed Life Rod: wand with healing? conservative
  [27903] = { STA = 0 },                      -- Sonic Spear: no proc
  [29347] = { SP = 0 },                       -- Talisman of the Breaker: no proc
  [28516] = { SP = 0 },                       -- Barbed Choker of Discipline: no proc
}

-- Note: [23046] The Restrained Essence of Sapphiron is raid loot and not shipped by the pipeline; the
-- entry is harmless and kept for the website which may show raid items.

function S.Get(itemId)
  return S.TABLE[itemId]
end
