# Pixel Blade Hub v4.0 — Full Reference

> Target: **[?2x WISHES!] Pixel Blade** · Roblox Place `18172550962`  
> Script: `pixel_blade_hub.lua` (2,699 lines) · Loads via `loadstring(game:HttpGet(...))()`  
> Everything below was extracted from the official place files (Lobby + W1–W5), not guessed.

---

## 1. Quick start

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/AlexanderRyl/BUN-HUB/main/pixel_blade_hub.lua"))()
```

* A round **PB** button appears on the right edge — **tap to open/close**, **drag to move**.
* `RightShift` also toggles the menu (changeable in the Player tab).
* Re-running the script always unloads the previous copy first — hot reload is safe.
* Full unload: `PixelBladeHubCleanup()`

If GitHub serves a stale copy, bust the cache with `...?v=2`.

### Suggested first setup

| Tab | Turn on |
|---|---|
| Combat | `Kill Aura`, `TRUE IMMORTAL`, `Infinite cooldowns`, `Auto skills` |
| Runs | `Auto play / join quest`, `Auto accept quest`, `Auto pick charm card`, `Leave when quest done` |
| Loot | `Auto collect drops`, `Auto open chests` (Royal, x10) |
| Fishing | `Auto fish`, `Auto equip bait`, `Auto sell` — tune `Perfect catch burst` upward |
| Inventory | Open the Armory in game once, then `Auto upgrade items` |

---

## 2. The game

### 2.1 Worlds (PlaceId)

Five story worlds plus a bootcamp and four raid variants. Each world has **3 chapters**.

| # | PlaceId | Display | Final boss | Minibosses |
|---|---|---|---|---|
| — | `Bootcamp` | Bootcamp | TutorialBoss | — |
| W1 | `Grasslands` | Grasslands | **Kingslayer** | John, GiantGoblin |
| W2 | `AncientSands` | Ancient Sands | **Atticus** | Maneater, Nekros |
| W3 | `HauntedTundra` | Haunted Tundra | **Kori** | ShimBombo, Akuma |
| W4 | `CrimsonAbyss` | Crimson Abyss | **Korth** | Gatekeeper, InfestedBeast |
| W5 | `SunkenDepths` | Sunken Depths | **Morvik** | DrownedGladiator, Ancient |
| R1–R4 | `GrasslandsRaid`, `AncientSandsRaid`, `HauntedTundraRaid`, `CrimsonAbyssRaid` | Raid versions | — | — |

### 2.2 Difficulty (PlaceDifficulty)

| Mode | Enemy HP | Enemy damage |
|---|---|---|
| `Normal` | x1.00 | x1.00 |
| `Heroic` | x1.40 | x1.20 |
| `Nightmare` | x1.85 | x1.45 |

Player scaling per world index (DPS / health):

| World | Player DPS | Player health |
|---|---|---|
| W1 | 35 / 70.2 / 105.3 | 150 / 225 / 300 |
| W2 | 190 / 247 / 321 | 435 / 500 / 575 |
| W3 | 578 / 751 / 976 | 834 / 959 / 1103 |
| W4 | 1757 / 2284 / 2969 | 1599 / 1839 / 2115 |
| W5 | 5344 / 6947 / 9031 | 3067 / 3527 / 4056 |

(three values = solo / duo / party). Enemy classes: `Grunt`, `Strong`, `Miniboss`.

### 2.3 Quest chain (official progression)

Each place/mode either **grants** a quest or **completes** one, which is what unlocks the next tier.

| Place | Normal | Heroic | Nightmare |
|---|---|---|---|
| Grasslands | given `CG_02` | given `CG_07` | completes `CG_07` |
| AncientSands | completes `CG_07` | given `W2_C_08` | completes `W2_C_08` |
| HauntedTundra | completes `W2_C_08` | given `W3_C_08` | completes `W3_C_08` |
| CrimsonAbyss | completes `W3_C_08` | given `W4_C_08` | completes `W4_C_08` |
| SunkenDepths | completes `W4_C_08` | given `W5_C_08` | completes `W5_C_08` |

Quest id families: `BC_*` bootcamp · `CG_*` Clyde's Gorge · `W2_`–`W5_` per world ·
`IC_*` intermediate/chained · `LV_*` level · `VF_*` Void Fisher · `CT_*` Clyde's Tome · `FORGE_*`.

Quest start kinds: `Automatic`, `PreviousQuest`, `ReachLevel`, `TalkToNpc`, `FindNpcInWorld`, `OnItemPickup`.

### 2.4 Currencies & wallets

`Coins`, `Stardust`, `Dice`, `Wishes`, `Revives`, `RingUnveils`, `SuperRingUnveils`.

### 2.5 Rarity tiers

`Common` → `Rare` → `Epic` → `Legendary` → `Vaulted` (Vaulted is the top tier, above Legendary).

### 2.6 Enemies

Confirmed ids: `Archer`, `Giant`, `Lumberjack`, `Kingslayer`, `GiantGoblin`, `Maneater`,
`Nekros`, `ShimBombo`, `Akuma`, `Kori`, `Korth`, `Gatekeeper`, `InfestedBeast`,
`Morvik`, `DrownedGladiator`, `Atticus`, `Ancient`, `TutorialBoss`.

Time-to-kill targets: Grunt 2s, Strong 5s, Miniboss 40s (player-facing: 30/18/15s).

### 2.7 NPCs

`ClydeTheGuide`, `HodorTheHorderer`, `PlagueDoctor`, `Maren`, `Corvin`, `Nessa`, `Mill`,
`CaptainBrenna`, `TheCharmDealer`, `Cap`, `ThePortalWatch`, `TheBlacksmith`, `FinnTheFisher`.

---

## 3. Loot & economy

### 3.1 Drop counts per source

| Source | Item drops | XP |
|---|---|---|
| Enemy | 1–3 | 1–3 |
| Miniboss | 10–20 | 12–20 |
| Boss | 50–100 | — |
| Breakable | 0–3 | — |
| BreakableChest | 3–4 | — |
| Parkour | — | 2–4 |
| SoulTreeRose | — | 1–2 |
| PuzzleChest | — | 2–4 |
| DarkChest | — | 1–5 |

Rarity weights: Common 10% · Rare 2% · Epic 0.1333% · Legendary 0.04%.
A chest never gives the same item twice — later drops skip items already dropped.
Bait conversion chance: 15%.

### 3.2 Chest tiers

`Wooden1`, `Wooden2` (Common) · `Royal1`, `Royal2` (Royal) · `Electric`, `AncientElectric` (Special) ·
`Legendary1` (Legendary) · `Daily` (Daily).

### 3.3 Gamepasses / shop ids

`Gold`, `Stardust`, `GodlyPotion`, `Revive`, `HealthFlask`, `EnergyFlask`, `DragonFlask`,
`WorldChest1`, `WorldChest2`, `WorldChest3`, `GroupChest`, `LegendaryChest`,
`EpicSuperCharm`, `EpicUltimateCharm`, `LegendarySuperCharm`, `LegendaryUltimateCharm`,
`CommonCharm`, `RareCharm`, `RareSuperCharm`, `Wish`, `Ring`, `SuperRing`, `ClassicRod`,
`Pages`, `Dice`, `RareWorldWeapon`, `EpicWorldWeapon`, `LegendaryWorldWeapon`.

---

## 4. Fishing

### 4.1 Baits — where to find them

| Bait | Found in |
|---|---|
| `Worms` | Grasslands |
| `CrabClaws` | Ancient Sands |
| `MiniSandworm` | Ancient Sands |
| `ArcticBerries` | Haunted Tundra |
| `GlowingEel` | Haunted Tundra |
| `FleshGrubs` | Crimson Abyss |
| `MagicEyeballs` | Crimson Abyss |
| `VoidSnail` | Sunken Depths |
| `AnglerFish` | Sunken Depths |

### 4.2 Catches

| Catch | Note |
|---|---|
| `FishGrey` | common |
| `FishBlue` | common |
| `FishCyan` | common |
| `StarfishBrown` | classic catch |
| `StarfishBlue` | classic catch |
| `StarfishPurple` | classic catch |
| `OldBoot` | trash — sell it |
| `Page` | **collect 8** to unveil an enchanted book — keep it |
| `FishGold` | incredibly rare, gold-covered — keep it |
| `GoldenTooth` | shiny, rare — keep it |
| `DarkKey` | "looks like it opens something" — keep it |

### 4.3 Rods

`ClassicPole`, `DynamicPole`, `IronPole`, `MihPulkSawPole`, `PythonPole`, `FrozenPole`,
`LunarPole`, `DarkFleshPole`, `GoldPole`, `WhiteRaven`, `DragonPole`, `Poltergeist`.

### 4.4 Charms

`Charm`, `SuperCharm`, `UltimateCharm` — the charm is **spent when the run begins** and is lost if you die.

### 4.5 Catch rating

Every catch is graded `Poor` / `Good` / `Perfect` / `Bad`. The grade comes from the timing of
`fishing_landed`. The hub's `Perfect catch burst` fires `fishing_landed` several times in quick
succession to land inside the perfect window regardless of your reaction time.

Wishing: every catch can hook a wish; the chance drops as you earn wishes today and resets daily.
Luck multiplies it. Shows as `1 IN {count}` and `{count}+ EARNED TODAY`.

---

## 5. Items

### 5.1 Weapons (33)

* **Common** — `Atlantis`, `Bone Blade`, `Cactus Sword`, `Dead Stick`, `Obsidian Stick`, `Rapier`
* **Rare** — `Black Ice`, `Black Star`, `Blood Sickle`, `Echo of the Slain`, `Fire Blade`, `Frost Blade`, `Ghost Katana`, `Tomb Hammer`
* **Epic** — `Crusher`, `Naginata`, `Ninja`, `Sinner`, `Stellar`, `Titan`, `Volt`, `Water Staff`, `Wing Blade`
* **Legendary** — `Chained Daggers`, `Chronos Blade`, `Crystal Scythe`, `Dragon's Heart`, `Excalibur`, `Flesh Scythe`, `Hellscape Scythe`, `Ice Spear`, `Ink Gauntlets`, `Vampire Axe`
* **Vaulted** — `Blink`, `Void Reaver`

Weapon kinds: `Sword`, `Scythe`, `Greatsword`, `Spear`, `DualBlades`, `Enemy`.
Roles: `Warrior`, `Alchemist`, `Necromancer`, `Knight`, `Paladin`, `Tree`, `ElementalWarden`,
`Reaper`, `Shroom`, `Townsperson`. Categories: `DPS`, `Healer`, `Tank`.

### 5.2 Armour (14)

| Armour | Rarity | Base HP |
|---|---|---|
| Chainmail | Common | 135 |
| Dragonfly Armor | Common | 170 |
| Bear Armor | Rare | 400 |
| Gold Armor | Epic | — |
| Molten Armor | Epic | 610 |
| Ninja Armor | Epic | 350 |
| Rogue Armor | Epic | — |
| Elden Armor | Legendary | — |
| Pharaoh Armor | Legendary | 390 |
| Soul Armor | Legendary | — |
| Valor Armor | Legendary | — |
| Halo | **Vaulted** | 790 |
| Chronos Armor | **Vaulted** | — |
| Void Reaper | **Vaulted** | — |

### 5.3 Weapon stats

`Damage`, `AttackSpeed`, `Range`, `WalkSpeed`, `FlameElement`, `Vampirism`, `FrostElement`,
`PoisonElement`, `SwingMoveSpeed`, `AbilityRecovery`, `HourGlassVitality`.

Armour/perk stat effects: `Speed`, `SpiritSpeed`, `SpiritEnergy`, `EnergyRegen`, `DamageTaken`,
`ParryDamage`, `ParryStunLength`, `AirDamage`, `GroundDamage`, `AbilityDamage`, `AbilityCooldown`,
`SpeedDamageMult`, `Health`, `BaseDamage`, `MaxStamina`, `PotionBoost`, `AbilityStaminaConsumption`,
`RegenShieldAmt`, `DashRegenTime`, `SpiritHeal`, `SpiritDamage`, `CampfireHeal`, `BerserkDamageMult`,
`CritDamage`, `SpiritCollectRange`, `SmiteChance`, `MinionChance`, `WindGust`, `LootDrops`,
`DoubleJump`, `SpearConsumptionCancel`, `SpearChargeCooldown`, `SpiritsHealAll`.

### 5.4 Stars & tiers

Weapons carry `stars` 1–4 (`One`..`Four`); some armour reaches 5 (Chronos). Tiers 1+ each grant
`ABILITY AT TIER {tier}` plus tier bonuses, and a chest is `x{count}` for bulk copies.

### 5.5 Companions

`None`, `MiniKingslayer`, `RavenCompanion`, `MiniQueenSlime`, `MiniDemon`, `Cerberus`,
`CatCompanion`, `MiniAtticus`, `GoldenAtticus`.

### 5.6 Runes / enchants / rings

* Runes: `unveil_ring`, `refine_ring` (+`{amount} STARDUST` per tier), `melt_ring`.
* Enchants: `roll_enchant`, `merge_enchants` (pick two books), `sell_enchant`.
  Books come from `Page` catches — **8 pages unveils one enchanted book**.

---

## 6. Titles & achievements

`NoviceSlayer`, `Hunter`, `Reaper`, `Annihilator`, `GrasslandsHero`, `GrasslandsGod`,
`DesertHero`, `DesertGod`, `TundraHero`, `TundraGod`, `CrimsonHero`, `CrimsonGod`,
`LegendaryFinder`, `LegendaryCollector`, `LegendaryHoarder`, `Defender`, `Immortal`,
`RaidsChampion`, `VoidFisher`, `ProFisher`, `VoidMaster`, `FishDinner`, `Enchanter`,
`BookWorm`, `SeekerOfAll`.

**SystemEvents** the game tracks (all fire via `claim_achievement` / quest rewards):
`Kill`, `RunComplete`, `EnterPlace`, `ReachChapter`, `ReachLevel`, `Catch`, `CharmCatch`,
`BaitCollect`, `BreakProps`, `FellScenery`, `OpenChest`, `Equip`, `Upgrade`, `BannerPick`,
`Parry`, `SkillUse`, `CampfireRest`, `ClientReport`, `TalkToNpc`, `EquipCharm`, `CharmPick`,
`BuyPotion`, `EquipPotion`, `DrinkPotion`, `RingObtain`, `RingCollect`, `RingRefine`,
`FishSell`, `DarkChestOpen`, `RingEquip`, `Material`, `Manual`.

---

## 7. Complete remote reference

All **204** remotes under `ReplicatedStorage._network_remotes`.
**Hub uses it** marks the 47 the script actually fires.

### Session / Run control

| Remote | Type | Hub uses it |
|---|---|---|
| `create_play_session` | RE | yes |
| `join_pad` | RE |  |
| `start_pad_session` | RE |  |
| `quit_pad` | RE |  |
| `extend_pad_for_invite` | RE |  |
| `update_pad_selection` | RE |  |
| `leave_run` | RE | yes |
| `spectate_focus` | RE |  |
| `run_end_vote` | RE | yes |
| `accept_run_earnings` | RE | yes |
| `show_teleport_screen` | RE |  |
| `update_play_menu_arc` | RE |  |
| `player_activity` | RE |  |
| `update_touch_layout` | RE |  |

### Quests / NPCs / Dialogue

| Remote | Type | Hub uses it |
|---|---|---|
| `accept_quest` | RE | yes |
| `quest_client_event` | RE | yes |
| `set_quest_collapsed` | RE |  |
| `set_quest_tracker_collapsed` | RE |  |
| `npc_dialogue` | RE | yes |
| `ftue_advance` | RE |  |
| `bootcamp_beat` | RE |  |
| `event_follow_prompted` | RE |  |
| `arc_revealed` | RE |  |
| `arc_2_intro_seen` | RE |  |

### Combat / Damage

| Remote | Type | Hub uses it |
|---|---|---|
| `activate_weapon` | RE | yes |
| `replicate_hit` | RE |  |
| `hit_denied` | RE |  |
| `knockback` | RE |  |
| `wall_chip` | RE |  |
| `send_drops` | RE |  |
| `collect_drop` | RE | yes |
| `drops_settled` | RE |  |
| `spawn_spirit` | RE |  |
| `collect_spirit` | RE | yes |
| `request_revive` | RE | yes |
| `give_up` | RE |  |
| `reset_character` | RE |  |
| `companion_hit` | RE |  |
| `shed_drenched` | RE |  |

### World puzzles / interactables

| Remote | Type | Hub uses it |
|---|---|---|
| `open_parkour_gate` | RE | yes |
| `solve_parkour_vault` | RE | yes |
| `claim_parkour_chest` | RE | yes |
| `press_door_button` | RE | yes |
| `claim_soul_tree_rose` | RE | yes |
| `claim_puzzle_key` | RE | yes |
| `open_puzzle_door` | RE | yes |
| `pull_puzzle_lever` | RE | yes |
| `claim_puzzle_chest` | RE | yes |
| `open_dark_chest` | RE | yes |

### Chests / Loot / Wishes

| Remote | Type | Hub uses it |
|---|---|---|
| `open_chest` | RE | yes |
| `chest_open_result` | RE |  |
| `mark_item_seen` | RE |  |
| `open_wish` | RE |  |
| `wish_result` | RE |  |
| `wish_refused` | RE |  |
| `purchase_reveal` | RE |  |
| `unveil_ring` | RE |  |
| `unveil_ring_result` | RE |  |
| `equip_ring` | RE |  |
| `refine_ring` | RE |  |
| `melt_ring` | RE |  |
| `reward_pickups` | RE |  |

### Fishing

| Remote | Type | Hub uses it |
|---|---|---|
| `toggle_rod` | RE | yes |
| `fishing_cast` | RE | yes |
| `fishing_reel` | RE | yes |
| `fishing_cancel` | RE |  |
| `fishing_landed` | RE | yes |
| `fishing_bite` | RE |  |
| `fishing_denied` | RE |  |
| `fishing_caught_item` | RE |  |
| `fishing_caught_charm` | RE |  |
| `fishing_caught_wish` | RE |  |
| `sell_fish_catch` | RE | yes |
| `sell_fish_charm` | RE | yes |
| `buy_fishing_rod` | RE |  |
| `equip_fishing_rod` | RE |  |
| `equip_fishing_bait` | RE | yes |
| `upgrade_fishing_stash` | RE | yes |

### Armory / Inventory

| Remote | Type | Hub uses it |
|---|---|---|
| `equip_item` | RE | yes |
| `upgrade_item` | RE | yes |
| `roll_class` | RE |  |
| `class_roll_result` | RE |  |
| `select_banner` | RE |  |
| `update_armory_sort` | RE |  |
| `update_chronos_form` | RE |  |
| `unlock_chronos_form` | RE |  |
| `evolve_chronos` | RE |  |
| `equip_charm` | RE |  |
| `pick_charm_card` | RE | yes |
| `equip_title` | RE |  |
| `equip_companion` | RE |  |
| `equip_potion` | RE |  |
| `buy_potion` | RE |  |
| `use_potion` | RE | yes |
| `roll_enchant` | RE |  |
| `enchant_roll_result` | RE |  |
| `sell_enchant` | RE |  |
| `merge_enchants` | RE |  |
| `equip_enchant` | RE |  |

### Raids / Party

| Remote | Type | Hub uses it |
|---|---|---|
| `set_raid_browser_open` | RE |  |
| `raid_browser_sync` | RE |  |
| `join_raid_server` | RE |  |
| `auto_join_raid` | RE | yes |
| `create_raid_server` | RE |  |
| `search_raid_owner` | RE |  |
| `raid_search_result` | RE |  |
| `update_raid_server_config` | RE |  |
| `raid_server_moderate` | RE |  |
| `raid_server_title` | RE |  |
| `leave_raid_lobby` | RE |  |
| `request_raid_admin_info` | RE |  |
| `raid_admin_info` | RE |  |
| `delete_raid_server` | RE |  |
| `invite_to_party` | RE |  |
| `respond_party_invite` | RE |  |
| `leave_party` | RE |  |
| `party_deny` | RE |  |
| `party_sound` | RE |  |

### Rewards / Codes / Daily

| Remote | Type | Hub uses it |
|---|---|---|
| `claim_achievement` | RE | yes |
| `claim_daily_reward` | RE | yes |
| `claim_code` | RE | yes |
| `code_claim_result` | RE |  |
| `code_reveal` | RE |  |
| `buy_daily` | RE |  |
| `shop_result` | RE |  |
| `notification_opt_in_attempted` | RE |  |
| `notification_reach_report` | RE |  |
| `daily_reward_presented` | RE |  |
| `bundle_offer_seen` | RE |  |
| `set_creator_code` | RE |  |
| `set_gift_recipient` | RE |  |

### Boss beats / minigames

| Remote | Type | Hub uses it |
|---|---|---|
| `korth_skill_check` | RE | yes |
| `morvik_bubble_break` | RE | yes |
| `gatekeeper_beam_dodged` | RE | yes |
| `enemy_ground_held` | RE | yes |
| `spawn_ground_held` | RE |  |

### Stations / Flying / Cutscenes

| Remote | Type | Hub uses it |
|---|---|---|
| `toggle_station` | RE |  |
| `station_fire` | RE |  |
| `update_station_aim` | RE |  |
| `set_gliding` | RE |  |
| `skip_cutscene` | RE | yes |
| `wind_gust_fx` | RE |  |
| `rescue_fallen` | RE | yes |
| `hub_station_used` | RE |  |
| `hub_station_left` | RE |  |

### Settings / Social

| Remote | Type | Hub uses it |
|---|---|---|
| `update_player_setting` | RE |  |
| `system_chat` | RE |  |
| `leave_party` | RE |  |

### Developer / Debug (may be server-gated)

| Remote | Type | Hub uses it |
|---|---|---|
| `debug_cycle_weapon` | RE |  |
| `weapon_bench_save` | RE |  |
| `debug_kill_all` | RE | yes |
| `debug_teleport_next_room` | RE | yes |
| `debug_jump_boss_wave` | RE | yes |
| `debug_cycle_armor` | RE |  |
| `debug_adjust_tier` | RE |  |
| `debug_adjust_stars` | RE |  |
| `debug_apply_stars` | RE |  |
| `tester_spawn_enemy` | RE |  |
| `tester_clear_enemies` | RE |  |
| `bot` | RE |  |
| `send_updates` | RE |  |
| `send_unreliables` | RE |  |

### Other / infrastructure

| Remote | Type | Hub uses it |
|---|---|---|
| `server_registered` | RE |  |
| `ping` | RE |  |
| `client_registered` | RE |  |
| `update_server_data` | RE |  |
| `send_mouse_pointer` | RE |  |
| `send_mouse_entity` | URE |  |
| `validate_query` | RE |  |
| `validate_result` | RE |  |
| `replicate_query` | RE |  |
| `disconnect_query` | RE |  |
| `advance_query_page` | RE |  |
| `pause_query` | RE |  |
| `refresh_query` | RE |  |
| `update_query_result` | URE |  |
| `count_total_entities` | URE |  |
| `initiate_replicate_scheduler` | RE |  |
| `disconnect_replicate_scheduler` | RE |  |
| `scheduler_system_update_static` | RE |  |
| `append_frame_system` | URE |  |
| `scheduler_pause` | RE |  |
| `validate_entity_component` | RE |  |
| `validate_entity_component_result` | RE |  |
| `inspect_entity` | RE |  |
| `get_entity_component` | RE |  |
| `return_entity_component` | RE |  |
| `delete_entity` | RE |  |
| `stop_inspect_entity` | RE |  |
| `update_entity` | RE |  |
| `inspect_entity_settings_update` | RE |  |
| `inspect_entity_update` | RE |  |
| `create_watch` | RE |  |
| `remove_watch` | RE |  |
| `request_watch_data` | RE |  |
| `update_watch_data` | RE |  |
| `start_record_watch` | RE |  |
| `stop_watch` | RE |  |
| `clear_watch` | RE |  |
| `connect_to_watch` | RE |  |
| `disconnect_watch` | RE |  |
| `update_watch_overview` | URE |  |
| `play_deny` | RE |  |
| `raid_deny` | RE |  |
| `receive_full` | RF |  |

---

## 8. Client module reference

The game is ECS-based (`src.vendor.jecs`) with systems taking `(world, ...)`.

### 8.1 `src.client.*` (422 modules)

`action_sound_util`  `airborne_util`  `animation_util`
`armor_dress_util`  `armor_stat_util`  `armory_chronos_evolve_util`
`armory_chronos_form_util`  `armory_dormancy_util`  `armory_enchant_util`
`armory_ftue_util`  `armory_gui_util`  `armory_intents`
`armory_notice_util`  `armory_ring_util`  `armory_sort_util`
`armory_stat_util`  `armory_upgrade_rows_util`  `armory_upgrade_util`
`armory_xp_util`  `arrival_util`  `astral_ghost_util`
`banner_stat_util`  `body_spin_util`  `bootcamp_tutorial_util`
`buff_hint_util`  `buff_util`  `camera_controller_util`
`camera_occlusion_util`  `camera_shake_channel`  `character_hide_util`
`charm_intents`  `chest_open_util`  `chronos_evolve_util`
`chronos_form_row_util`  `chronos_form_util`  `cinematic_stage_util`
`class_body_particle_util`  `client_model_util`  `clyde_bubble_util`
`code_intents`  `combat_hud_intents`  `command_console_util`
`cutscene_hand_back_util`  `cutscene_move_util`  `daily_rewards_intents`
`damage_counter_util`  `dialogue_camera_util`  `difficulty_hint_util`
`drops.drop_collect_fx_util`  `drops.drop_model_util`  `effect_policy_util`
`enchant_gui_util`  `enemy_beam_util`  `enemy_pointer_util`
`enemy_visibility_util`  `equip_anywhere_util`  `falling_particles_util`
`fishing_stash_util`  `fishing_ui_intents`  `follow_up_skill_util`
`frustum_util`  `ftue_guide_util`  `fx.armor.tidal_aura_fx`
`fx.authored_fx_util`  `fx.bleed_hit_fx`  `fx.block_debris_fx`
`fx.blood_reaper_util`  `fx.blood_tint_util`  `fx.classes.necromancer_summon_fx`
`fx.classes.paladin_smite_lightning`  `fx.damage_highlight_fx`  `fx.dash_fx`
`fx.debris_cover_util`  `fx.default_hit_fx`  `fx.effect_burst_fx`
`fx.enemies.ancient.blind_glow`  `fx.enemies.ancient.shadow_seep`  `fx.enemies.atticus.phase2_aura_fx`
`fx.enemies.bolt.bolt_lightning`  `fx.enemies.drowned_cyclops.ground_break`  `fx.enemies.drowned_cyclops.stomp_ring`
`fx.enemies.drowned_cyclops.torch_blast`  `fx.enemies.drowned_cyclops.torch_orb`  `fx.enemies.drowned_gladiator.net_catch`
`fx.enemies.gatekeeper.chain_charge`  `fx.enemies.ghost.ghost_vanish_smoke`  `fx.enemies.ice_golem.frost_nova`
`fx.enemies.ice_golem.frost_nova_growth_util`  `fx.enemies.illusionist.smoke_puff`  `fx.enemies.mortar_goblin.explosion`
`fx.enemies.obsidian_pyromancer.fire_pillar`  `fx.enemies.obsidian_pyromancer.flame_stream`  `fx.enemies.raid_boss.ash_flame_fx`
`fx.enemies.raid_boss.glacien_bow_fx`  `fx.enemies.raid_boss.helios_star_fx`  `fx.enemies.raid_boss.planted_sword_util`
`fx.enemies.raid_boss.raid_ignition_util`  `fx.enemies.raid_boss.rock_wall_fx`  `fx.enemies.raid_boss.stomp_wave`
`fx.enemies.raid_boss.teleport_portal_fx`  `fx.enemies.shim_bombo_yeti.icicle_land`  `fx.enemies.shim_bombo_yeti.snowball_burst`
`fx.enemies.sniper_skeleton.laser_sight`  `fx.enemies.sniper_skeleton.muzzle_flash`  `fx.enemies.tombstone_goblin.summon_highlight`
`fx.fx_budget_util`  `fx.fx_hue_util`  `fx.garage_burst_fx`
`fx.level_up_fx`  `fx.morvik_wave_util`  `fx.parry_fx_util`
`fx.particle_fx_util`  `fx.revive_flash_fx`  `fx.revive_fx`
`fx.rig_debris_util`  `fx.rig_emitter_util`  `fx.scenery.wisp_pop`
`fx.shockwave_fx`  `fx.skills.ablaze_fx`  `fx.skills.adrenaline_fx`
`fx.skills.angels_bane_fx`  `fx.skills.blade_dash_fx`  `fx.skills.blaze_burn_fx`
`fx.skills.blind_eye_fx`  `fx.skills.blood_thirst_fx`  `fx.skills.blue_streak_fx`
`fx.skills.bone_strength_fx`  `fx.skills.chain_links_fx`  `fx.skills.chain_wrap_fx`
`fx.skills.chronos_fx`  `fx.skills.clockwork_fx`  `fx.skills.death_sentence_fx`
`fx.skills.earthquake_fx`  `fx.skills.falling_sword_fx`  `fx.skills.gemstone_bubble_fx`
`fx.skills.gemstone_smash_fx`  `fx.skills.golden_eclipse_fx`  `fx.skills.ice_cube_fx`
`fx.skills.katar_frenzy_fx`  `fx.skills.katar_throw_fx`  `fx.skills.lightning_beam_fx`
`fx.skills.mace_crater_fx`  `fx.skills.reaver_domain_fx`  `fx.skills.rejuvenate_fx`
`fx.skills.sand_tornado_fx`  `fx.skills.smash_fx`  `fx.skills.smokebomb_smoke_fx`
`fx.skills.spikes_fx`  `fx.skills.spirit_warp_fx`  `fx.skills.subzero_fx`
`fx.skills.time_disruption_fx`  `fx.skills.tornado_fx`  `fx.skills.venom_fx`
`fx.skills.void_hit_smash_fx`  `fx.skills.weeping_touch_explosion_fx`  `fx.skills.wing_smash_slam_fx`
`fx.stack_vfx`  `fx.thorn_snare_fx`  `fx.weapon_slash_fx`
`fx.world.sky_flash_util`  `fx.world.storm_cloud`  `fx.world.storm_gust`
`fx.world.storm_rain`  `fx.world.storm_strike`  `gift_recipient_util`
`ground_held_util`  `ground_ray_util`  `group_util`
`gui_adornee_util`  `highlights.highlight_util`  `hit_feel_lookup_util`
`hit_feel_util`  `hitbox_util`  `hub_prompt_util`
`hub_station_intents`  `indicator_text_util`  `kori_snowball_util`
`lobby_npc_util`  `loot_hint_util`  `loot_preview_util`
`maneater_cue_util`  `menu_interrupt_util`  `menu_lighting_util`
`menu_state_util`  `modal_ui_util`  `mortar_shell_util`
`npc_dialogue_intents`  `npc_focus_util`  `number_format_util`
`odds_text_util`  `pad_presence_util`  `party_intents`
`play_intents`  `player_control_util`  `player_tag_util`
`profile_intents`  `projectile_util`  `purchase_policy_util`
`quest_reward_gui_util`  `raid_intents`  `raid_server_intents`
`revive_intents`  `rig_dress_util`  `ring_gui_util`
`robux_price_util`  `role_tag_util`  `roster_collapse_util`
`run_end_intents`  `scaled_text_util`  `screen_region_util`
`settings_intents`  `shiftlock_util`  `shop_intents`
`shop_item_util`  `show_user_profile`  `sound_effects`
`sound_groups`  `spectate_intents`  `spectate_util`
`spirits.spirit_orb_util`  `stash_upgrade_util`  `station_intents`
`storm_flash_channel`  `storm_thunder_util`  `systems.activate_weapons`
`systems.camera_system`  `systems.profile_hover`  `systems.render_armor`
`systems.render_class_bodies`  `systems.render_enemy_health_bar`  `systems.ui.shop`
`tab_menu_intents`  `title_line_util`  `title_picker_util`
`toolbar_intents`  `touch_pad_art_util`  `touch_pad_hit_util`
`touch_pad_press_util`  `touch_pad_slot_util`  `tutorial_spotlight_util`
`ui.banner_style`  `ui.components.ftue_pointer`  `ui.components.notice_badge`
`ui.components.pad_face`  `ui.components.skip_prompt`  `ui.core.alpha_channel`
`ui.core.binding`  `ui.core.box`  `ui.core.easing`
`ui.core.edge_slide`  `ui.core.element`  `ui.core.fit`
`ui.core.focus`  `ui.core.follow`  `ui.core.font_metrics`
`ui.core.frame_pump`  `ui.core.gradient`  `ui.core.input_mode`
`ui.core.localization`  `ui.core.media`  `ui.core.rem_context`
`ui.core.screen_host`  `ui.core.shadow`  `ui.core.style`
`ui.core.text`  `ui.core.theme`  `ui.core.use_rem`
`ui.crosshair`  `ui.item_card_style`  `ui.kit.control.button`
`ui.kit.control.chip`  `ui.kit.control.close_x`  `ui.kit.control.select`
`ui.kit.control.stepper`  `ui.kit.control.tabs`  `ui.kit.data.avatar`
`ui.kit.data.boost_badge`  `ui.kit.data.drop_list`  `ui.kit.data.identity_line`
`ui.kit.data.item_card`  `ui.kit.data.list_row`  `ui.kit.data.meter`
`ui.kit.data.reward_card`  `ui.kit.fade`  `ui.kit.fx.bar_impact`
`ui.kit.fx.pixel_fx`  `ui.kit.overlay.end_fade`  `ui.kit.overlay.hover_hint`
`ui.kit.overlay.input_blocker`  `ui.kit.overlay.modal`  `ui.kit.overlay.scroll_region`
`ui.kit.overlay.toast`  `ui.kit.overlay.tooltip`  `ui.kit.primitives.divider`
`ui.kit.primitives.glyph`  `ui.kit.primitives.icon`  `ui.kit.primitives.key_cap`
`ui.kit.primitives.pip`  `ui.kit.primitives.text`  `ui.kit.screen`
`ui.kit.surface.layers`  `ui.kit.surface.shadow`  `ui.kit.surface.surface`
`ui.korth_skill_check`  `ui.pad_billboard`  `ui.rem`
`ui.screens.armory`  `ui.screens.armory.chest_reveal`  `ui.screens.armory.cinema`
`ui.screens.armory.class_parts`  `ui.screens.armory.enchant_actions_block`  `ui.screens.armory.enchant_readout`
`ui.screens.armory.evolve_block`  `ui.screens.armory.evolve_confirm_modal`  `ui.screens.armory.evolve_info_modal`
`ui.screens.armory.evolve_layer`  `ui.screens.armory.forms_row`  `ui.screens.armory.parts`
`ui.screens.armory.potion_slot_row`  `ui.screens.armory.ring_actions_block`  `ui.screens.armory.roll_cinema`
`ui.screens.armory.upgrade_modal`  `ui.screens.armory.xp_bar`  `ui.screens.banner_picker`
`ui.screens.banner_picker.card`  `ui.screens.banner_picker.face`  `ui.screens.banner_picker.parts`
`ui.screens.boss_healthbar`  `ui.screens.boss_healthbar.layout`  `ui.screens.boss_healthbar.parts`
`ui.screens.charm_equip`  `ui.screens.charm_pick`  `ui.screens.cinematic_skip`
`ui.screens.combat_hud`  `ui.screens.combat_hud.action_slot`  `ui.screens.combat_hud.hurt`
`ui.screens.combat_hud.loot_ticker`  `ui.screens.combat_hud.objective`  `ui.screens.combat_hud.pad_slot`
`ui.screens.combat_hud.parts`  `ui.screens.combat_hud.party_cards`  `ui.screens.combat_hud.rewind_sign`
`ui.screens.combat_hud.slot_readout`  `ui.screens.combat_hud.status_row`  `ui.screens.combat_hud.touch_pad`
`ui.screens.combat_hud.vitals`  `ui.screens.cutscene`  `ui.screens.earned_items`
`ui.screens.fish_shop.detail_panel`  `ui.screens.fish_shop.parts`  `ui.screens.fishing_hud.parts`
`ui.screens.fishing_stash.strip`  `ui.screens.game_end`  `ui.screens.game_end.lane`
`ui.screens.game_end.parts`  `ui.screens.game_end.plate`  `ui.screens.join_pad_prompt`
`ui.screens.join_pad_prompt.band`  `ui.screens.load_in`  `ui.screens.load_in.logo`
`ui.screens.load_in.parts`  `ui.screens.load_in.status`  `ui.screens.lobby_pickups`
`ui.screens.lobby_roster`  `ui.screens.pad_status.parts`  `ui.screens.play_menu`
`ui.screens.play_menu.arc_arrows`  `ui.screens.play_menu.arc_reveal`  `ui.screens.play_menu.arc_transition`
`ui.screens.play_menu.clouds`  `ui.screens.play_menu.deep_sea`  `ui.screens.play_menu.loot_preview`
`ui.screens.play_menu.parts`  `ui.screens.play_menu.sea`  `ui.screens.profile`
`ui.screens.profile.parts`  `ui.screens.profile.title_picker`  `ui.screens.quest_tracker`
`ui.screens.raid_browser`  `ui.screens.raid_browser.admin_panel`  `ui.screens.raid_browser.parts`
`ui.screens.raid_browser.search_bar`  `ui.screens.raid_browser.server_row`  `ui.screens.raid_server_config`
`ui.screens.raid_server_config.level_slider`  `ui.screens.raid_server_config.parts`  `ui.screens.raid_server_config.roster_row`
`ui.screens.revive_screen`  `ui.screens.revive_screen.parts`  `ui.screens.settings`
`ui.screens.settings.row`  `ui.screens.settings.section`  `ui.screens.shop`
`ui.screens.shop.bundles`  `ui.screens.shop.gift_picker`  `ui.screens.shop.parts`
`ui.screens.spectate_hud`  `ui.screens.spectate_hud.chip`  `ui.screens.spectate_hud.parts`
`ui.screens.stage_marker`  `ui.screens.stage_marker.layout`  `ui.screens.stage_marker.parts`
`ui.screens.station_controls`  `ui.screens.tab_menu`  `ui.screens.tab_menu.banner_row`
`ui.screens.tab_menu.confirm`  `ui.screens.tab_menu.equip_anywhere`  `ui.screens.tab_menu.layout`
`ui.screens.tab_menu.palette`  `ui.screens.toolbar`  `ui.screens.tutorial_hud`
`ui.screens.wishes`  `ui.screens.wishes.browse`  `ui.screens.wishes.measure`
`ui.screens.wishes.parts`  `ui_mode_util`  `user_input`
`wish_cinematic_util`  `wish_intents`  `wish_scene_util`
`wish_upgrade_util`  `xp_climb_util`

### 8.2 `src.configs.*` (119 modules)

`arc_2_intro_caption_config`  `arc_2_intro_config`  `armor_attributes`
`armor_passive_config`  `armor_tier_config`  `armory_config`
`armory_menu_config`  `armory_thumbnail_config`  `armory_tooltip_config`
`attributes`  `banner_picker_config`  `banner_upgrade_config`
`bootcamp_script_config`  `boss_healthbar_config`  `breakable_config`
`buff_tracker_config`  `chapter_config`  `charm_config`
`chest_config`  `chest_display_config`  `chest_families`
`chest_open_config`  `chronos_evolution_config`  `chronos_form_config`
`chronos_form_unlock_config`  `cinematic_caption_config`  `class_config`
`class_menu_config`  `clyde_config`  `code_config`
`combat_hud_config`  `companion_config`  `completed_config`
`currency_drop_config`  `cutscene_config`  `daily_rewards_config`
`damage_counter_config`  `dev_environment_config`  `drench_storm_config`
`drop_config`  `drowned_cyclops_config`  `effect_policy_config`
`elemental_config`  `enchant_config`  `enemy_banner_config`
`enemy_info`  `enemy_overlay_config`  `enemy_scaling_config`
`fishing_config`  `ftue_config`  `game_config`
`gameplay`  `held_back_items_config`  `hit_feel_config`
`hotkey_icons_config`  `hotkey_text_config`  `hour_glass_config`
`hub_station_config`  `hud_buttons_config`  `indicator_config`
`item_grant_config`  `item_name_config`  `knockback_config`
`load_in_config`  `lobby_npc_config`  `loot_preview_config`
`mace_smash_config`  `maneater_config`  `matchmaking_config`
`morvik_config`  `nightmare_variant_config`  `parkour_config`
`party_config`  `permissions`  `place_names`
`play_config`  `player_xp_config`  `potion_config`
`puzzle_room_config`  `quest_item_config`  `quest_line_config`
`quest_reward_config`  `quest_track_config`  `quests`
`raid_config`  `raid_server_config`  `ring_config`
`ring_unveil_config`  `room_reinforcement_config`  `run_end_config`
`run_level_config`  `settings_config`  `shadow_boots_config`
`shop_config`  `shop_menu_config`  `social_config`
`soul_orb_config`  `spirit_config`  `stack_config`
`station_config`  `sunken_depths_dressing_config`  `tab_menu_config`
`tags`  `time_traveller_config`  `title_config`
`ui_theme_config`  `weapon_hitbox_sizes`  `weapon_stats.rarity_config`
`weapon_stats.star_ranges`  `weapon_stats.stat_modifiers`  `weapon_stats.weapon_attributes`
`weapon_type_map`  `wish_event_config`  `wish_reveal_config`
`world_map_config`  `world_map_polygons`  `world_map_scene_config`
`world_unlock_config`  `world_unlock_rules`

### 8.3 `src.*` core modules (149)

`ability_text_util`  `ability_tier_util`  `achievement_util`
`action_sequences`  `ancient_blink_util`  `arc_2_intro_util`
`armor_passive_util`  `armor_tier_util`  `armor_util`
`assets`  `attachment_util`  `banner_upgrade_modifier_util`
`bone_stick_util`  `bootcamp_lesson_util`  `bootcamp_phase_util`
`campfire_giver_util`  `charm_bag_util`  `chest_label_util`
`chest_odds_util`  `chest_progress_util`  `chronos_evolution_util`
`chronos_form_unlock_util`  `class_appearance_util`  `class_util`
`clyde_presence_util`  `clyde_walk_util`  `completed_util`
`cutscene_state_util`  `cutscenes`  `daily_reward_util`
`damage_color_util`  `damage_util`  `dash_util`
`day_cycle_util`  `double_wish_util`  `drenched_util`
`drop_burst_util`  `drop_pickup_util`  `elemental_stack_util`
`elf_statue_util`  `enchant_book_util`  `enchant_util`
`enemy_scaling_util`  `enemy_util`  `entity_attr`
`event_follow_util`  `face_nearest_enemy_util`  `fishing_unlock_util`
`fishing_walk_util`  `flesh_cannon_util`  `fractured_stack_util`
`fractured_time_util`  `friends_bonus_util`  `frozen_wall_util`
`ftue_save_util`  `ftue_util`  `gamepass_util`
`gatekeeper_chain_util`  `generators`  `grapple_bolt_util`
`heal_block_util`  `health_debt_util`  `hit_knockback_util`
`hitbox_util`  `hour_glass_util`  `hub_station_util`
`hurtbox_query`  `ink_decoy_util`  `item_util`
`joint_util`  `jump_pad_util`  `kori_flight_util`
`korth_beam_util`  `legendary_chest_util`  `line_target_util`
`live_progress_util`  `lobby_npc_costume_util`  `localization_util`
`model_ancestry_channel`  `morvik_bubble_util`  `morvik_phase_scene_util`
`morvik_scythe_util`  `nearest_target_util`  `network`
`octrees`  `opening_attack_cooldown_util`  `pad_seat_util`
`parry_lesson_util`  `permission_util`  `physics_owner_util`
`place_kind_util`  `player_data_util`  `player_settings_util`
`player_xp_util`  `potion_util`  `predictive_aim_util`
`prefabs`  `quest_item_util`  `quest_line_util`
`quest_text`  `quest_util`  `quest_weapon_roll_util`
`quest_world_util`  `raid_drop_util`  `raid_enemy_drop_util`
`raid_util`  `ranged_aim_util`  `raycast`
`replication_util`  `retribution_util`  `rigs`
`ring_util`  `room_reinforcement_util`  `room_util`
`run_xp_util`  `shop_lock_util`  `skill_cut_util`
`skill_energy_util`  `slime_hop_util`  `soul_orb_util`
`specter_arc_util`  `spend_title_util`  `spirit_util`
`spring_util`  `stash_capacity_util`  `stat_util`
`station_aim_util`  `summon_cap_util`  `summon_owner_util`
`target_point_util`  `term_text`  `time_traveller_util`
`title_reward_util`  `touch_layout_util`  `unlocked_band_util`
`unlocked_pool_util`  `unseen_item_util`  `upgrade_util`
`version_util`  `vortex_weight_util`  `weapon_mount_util`
`weapon_rng_util`  `weapon_stat_util`  `weapon_tier_util`
`weapons`  `wish_event_util`  `world_access_util`
`world_text`  `world_unlock_util`

### 8.4 Input bus

`ReplicatedStorage.src.client.user_input` exposes BindableEvents the game itself listens to:
`attack`, `skill_one`, `skill_two`, `aim_release`. Firing these is the *legitimate* input path —
prefer it over raw remotes. The hub uses it for attack, skills, dash and potion.

Related ECS components: `Attack`, `Activated`, `SkillAiming`, `Stun`, `Dead`, `Equipped`,
`EquippedWeapon`, `Weapon`, `Humanoid`, `RootPart`, `Glide`, `RodHeld`, `ProfileHoverHud`,
`ManningStation`, `VaultMinigame`.

---

## 9. Localization coverage

The game ships **59** localized string groups (1321 en-us keys parsed). Useful for reading
UI text straight out of the client:

| Group | Keys |
|---|---|
| `ui.armory` | 128 |
| `ui.ability_stat` | 120 |
| `ui.settings` | 72 |
| `ui.skill` | 66 |
| `ui.shop` | 60 |
| `ui.fishing` | 55 |
| `ui.wishes` | 55 |
| `ui.achievement` | 50 |
| `ui.fish_shop` | 41 |
| `ui.raid_browser` | 37 |
| `ui.class` | 36 |
| `ui.title` | 35 |
| `ui.tooltip` | 32 |
| `ui.enchant` | 30 |
| `ui.play` | 30 |
| `ui.buff_hint` | 29 |
| `ui.daily` | 29 |
| `ui.indicator` | 27 |
| `ui.touch_pad` | 25 |
| `ui.arc_2_intro` | 23 |
| `ui.evolve` | 21 |
| `ui.profile` | 20 |

Notable strings: `ui.armory.cooldown = "CD {seconds}s"`, `ui.fishing.rating_perfect = "Perfect!",
`ui.charm.your_charm_is_spent_when_the_run_begins`, `ui.fishing.fish_stash_full_sell_or_upgrade`,
`ui.play.deny.difficulty_locked = "You haven't unlocked that difficulty yet."`

---

## 10. How the hub works

### 10.1 Architecture

| Layer | Detail |
|---|---|
| Scheduler | **One** `RunService.Heartbeat` drives every timed job. 34 jobs, each with a gate, a `busy` flag and a one-shot error warning. |
| World scan | **One** cached scan every 0.2s shared by combat, ESP, drops and breakables. |
| Remotes | Cached by name, missing remotes retried every 5s — never spams `FindFirstChild`. |
| Enums | Resolved at runtime via `require`, with the key name as fallback. |
| Cleanup | 32 tracked connections/instances/functions destroyed by `PixelBladeHubCleanup()`. |
| GUI | Custom-built, `DisplayOrder 999`, `IgnoreGuiInset`, `gethui()` → `CoreGui` → `PlayerGui` fallback chain. |
| Config | JSON to `PixelBladeHub_v4.json`; cheat toggles are deliberately excluded from restore. |

### 10.2 Feature → remote map

| Hub feature | Calls |
|---|---|
| Kill aura / damage | `user_input.attack`, `activate_weapon(entity, aim, 1)` |
| Ignore armor | 3× `activate_weapon` with offset aim points |
| Auto next room | `debug_teleport_next_room(os.clock())`, else door/portal seek |
| Auto continue | `run_end_vote(1)`, `accept_run_earnings` |
| Leave when quest done | `leave_run()` |
| Auto play quest | `create_play_session(PlaceId, PlaceDifficulty, MaxPlayers)` |
| Auto accept quest | `accept_quest`, `npc_dialogue`, `quest_client_event` |
| Charm card | `pick_charm_card(index)` |
| Auto revive | `request_revive`, `rescue_fallen(userId)` |
| Potions | `use_potion(slot)` |
| Chests | `open_chest(ChestId, count)`, `open_dark_chest` |
| Drop vacuum | CFrame teleport of XP/loot parts |
| Destroy props | Local `Humanoid.Health = 0` on non-boss scenery |
| Auto fish | `fishing_cast`, `fishing_reel(true)`, `fishing_landed(os.clock())` |
| Perfect catch | repeated `fishing_landed` (burst) |
| Auto bait | `equip_fishing_bait(BaitId)` |
| Auto sell | `sell_fish_catch(id)`, `sell_fish_charm(tier)`, `upgrade_fishing_stash` |
| Stash counter | listens to `fishing_caught_item` / `_charm` / `_wish` |
| Auto upgrade | `equip_item`, `upgrade_item(entity)` |
| Boss dodging | `korth_skill_check(true)`, `morvik_bubble_break`, `gatekeeper_beam_dodged` |
| Clear room | `debug_kill_all`, `debug_jump_boss_wave` |

### 10.3 Config reference (89 options)

| Key | Default | What it does |
|---|---|---|
| `KillAura` | `false` | Auto-attacks the nearest valid enemy in `AttackRange`. |
| `AttackRate` | `0.08` | Seconds between attacks. Floor is 0.03s (max hit throughput). |
| `AttackRange` | `60` | Max distance the hub will engage, in studs. |
| `TargetPriority` | `"Closest"` | `Closest` / `LowestHP` / `BossFirst`. |
| `LockTarget` | `true` | Stick to one enemy until it dies or leaves range. |
| `AttackMethod` | `"Both"` | `Both` (signal + remote), `Input` (legit signal only), `Remote` (remote only). |
| `AutoSkills` | `false` | Fires `skill_one` + `skill_two` while in range. |
| `SkillInterval` | `0.45` | Seconds between skill fires. |
| `AutoDash` | `false` | Dodge/dash via the input bus. |
| `DashInterval` | `1.2` | Seconds between dashes. |
| `NoCooldown` | `true` | Sweeps the character every 0.1s and zeroes any cooldown-like attribute. |
| `IgnoreArmor` | `true` | Sends three `activate_weapon` aim points per swing so armour plates do not block the hitbox query. |
| `MaxHitRate` | `0.03` |  |
| `AutoPotionSlot` | `1` | Potion slot index sent with `use_potion`. |
| `PotionThreshold` | `45` | Health percent that triggers a potion. |
| `TrueImmortal` | `false` | MaxHealth -> 1e9, health pinned, Dead state disabled, invisible ForceField. |
| `IgnoreDamage` | `false` | Health pinned to max, death state disabled. |
| `HideFromBosses` | `false` | Signals the named boss beats (Korth beam, Morvik bubble, Gatekeeper). |
| `AutoUsePotions` | `true` | Drink when health drops below `PotionThreshold`. |
| `AutoTP` | `false` | Move the character to the locked target. |
| `TPMode` | `"Orbit"` | `Orbit` / `Behind` / `Above` / `Under` / `Stay`. |
| `TPDistance` | `16` | Vertical offset from the target. |
| `OrbitRadius` | `22` | Orbit circle radius. |
| `OrbitSpeed` | `180` | Degrees per second around the orbit. |
| `SelectedWorld` | `"Grasslands"` | Which world `create_play_session` requests. |
| `SelectedDifficulty` | `"Normal"` | `Normal` / `Heroic` / `Nightmare`. |
| `MaxPlayers` | `4` | Max players passed to `create_play_session`. |
| `AutoNextRoom` | `false` | `debug_teleport_next_room`, with a door/portal-seek fallback. |
| `NextRoomDelay` | `0.6` | Minimum delay between room advances. |
| `AutoBossWave` | `false` | `debug_jump_boss_wave` (developer remote, may be server-gated). |
| `AutoKillAll` | `false` | `debug_kill_all` (developer remote, may be server-gated). |
| `AutoRaid` | `false` | `auto_join_raid`. |
| `AutoContinue` | `false` | `run_end_vote` + `accept_run_earnings` after a run. |
| `ContinueDelay` | `3.0` | Seconds to wait before voting to continue. |
| `AutoLeaveOnQuest` | `false` | `leave_run` once the objective is done. |
| `LeaveAfterQuest` | `true` |  |
| `AutoAcceptQuest` | `false` | Fires `accept_quest` / `npc_dialogue` / `quest_client_event`. |
| `AutoPlayQuest` | `false` | Creates the session automatically with the selected world + mode. |
| `AutoCharmCard` | `true` | `pick_charm_card` before the run begins. |
| `CharmCardIndex` | `1` | Which charm card to take. |
| `AutoRevive` | `true` | `request_revive` + `rescue_fallen` for each party member. |
| `AutoSkipCutscene` | `true` | `skip_cutscene`. |
| `AutoDaily` | `true` | `claim_daily_reward`. |
| `AutoCodes` | `true` | Tries a small list of free codes via `claim_code`. |
| `AutoCollectDrops` | `true` | Vacuums XP and loot parts to the player. |
| `CollectRange` | `200` | Vacuum radius in studs. |
| `AutoOpenChests` | `true` | `open_chest(chestId, count)` on a loop. |
| `OpenChestSet` | `"Royal"` | Which chest tier set to open. |
| `OpenChestBulk` | `10` | How many chests to open per batch. |
| `AutoDarkChest` | `true` | `open_dark_chest`. |
| `DestroyProps` | `false` | Also kills breakables / scenery, not just bosses. |
| `AutoPrompts` | `true` | Fires chest and station `ProximityPrompt`s in range. |
| `PromptRange` | `45` | ProximityPrompt radius. |
| `AutoFish` | `false` | Full cast -> reel -> land loop. |
| `FastReel` | `true` | Skips the waiting window before reeling. |
| `ReelDelay` | `0.35` | Seconds between cast and reel. |
| `LandDelay` | `0.25` | Seconds between reel and land. |
| `LandBurst` | `3` | Extra `fishing_landed` calls to land inside the perfect window. |
| `AutoBait` | `true` | `equip_fishing_bait` every cycle. |
| `BaitSelect` | `"FleshGrubs"` | Which bait to equip. |
| `AutoSellFish` | `false` | Sells the configured fish once the stash hits `SellThreshold`. |
| `SellThreshold` | `20` | Catches before an auto-sell triggers (counted from `fishing_caught_item`). |
| `AutoUpgradeStash` | `false` | `upgrade_fishing_stash` alongside a sell. |
| `SellFishes` | `{ FishGrey = true, FishBlue = true, FishCyan = true` |  |
| `SellCharms` | `false` | Also sell the selected charm tier. |
| `SellCharmTier` | `"Charm"` | `Charm` / `SuperCharm` / `UltimateCharm`. |
| `AutoUpgrade` | `false` | Equips then upgrades held gear via `upgrade_item`. |
| `UpgradeCopies` | `2` | How many upgrade attempts per item per cycle. |
| `MaxUpgradeTier` | `10` | Stop upgrading an item at or above this tier. |
| `AutoEquipBest` | `false` | Re-equip before each upgrade attempt. |
| `AutoClaims` | `false` | `claim_achievement`. |
| `EnemyESP` | `true` | Highlight normal enemies. |
| `BossESP` | `true` | Highlight final + miniboss enemies in orange. |
| `ChestESP` | `true` | Label nearby chests with distance. |
| `DropESP` | `true` | Label nearby drops. |
| `Tracers` | `false` | Lines to enemies (needs a Drawing-capable executor). |
| `ESPRange` | `260` | ESP radius in studs. |
| `Fullbright` | `false` | Max brightness, no shadows, fixed clock time. |
| `NoFog` | `false` | Removes fog. |
| `WalkSpeedEnabled` | `false` | Overrides walk speed. |
| `WalkSpeedValue` | `48` | The overridden value. |
| `FlyEnabled` | `false` | Fly with WASD + Space / Shift. |
| `FlySpeed` | `55` | Fly velocity. |
| `InfJump` | `false` | Unlimited jumps. |
| `Noclip` | `false` | Disables collision on character parts. |
| `AntiAFK` | `true` | Dumps `VirtualUser` on `Idled`. |
| `Accent` | `"Purple"` | UI accent colour. |
| `MenuKey` | `"RightShift"` | Hotkey that toggles the menu (the floating button always works too). |
| `AutoSave` | `true` | Persist settings to `PixelBladeHub_v4.json`. |

---

## 11. Verification & honest limitations

### 11.1 What was verified

* Lua 5.5 parser — clean. No BOM, no CRLF, no Luau-only syntax.
* Static audit — 0 missing config keys, 0 missing UI functions, 0 duplicate jobs.
* **All 47 remotes the hub fires exist in the live game.**
* Executed against a Roblox API mock: top-level clean, 240 heartbeat frames with every
  feature enabled, no script-originated errors.
* World-scan logic unit-tested in isolation: 50 consecutive passes, correct boss detection.

### 11.2 Bugs this process caught (and fixed)

| Bug | Impact |
|---|---|
| `local function Enum()` shadowed Roblox's global `Enum` table | `Enum.ZIndexBehavior` / `Enum.HumanoidStateType` threw on the first frame — script was dead on arrival |
| `d:Parent == nil` | invalid syntax — `:` requires call arguments |
| `pcall(function() r:FireServer(...) end)` | `...` is illegal in a non-vararg closure |
| `continue` keyword | Luau-only; removed for portability |
| Health listener reconnected every 0.1s | connection leak during immortality |
| `SellFishes.X` set as a flat key | per-fish toggles wrote the wrong config slot |

### 11.3 Limitations — please read

* **Damage, armour and cooldowns are server-authoritative.** `Ignore Armor` and
  `Infinite cooldowns` work by maximising hit throughput and zeroing *client-visible*
  cooldown state. They are the two weakest features; everything else is backed by a real remote.
* **`debug_*` remotes are developer tools.** They exist in the shipped client but may be
  gated server-side in the live game. Treat `Auto kill everything` and `Jump to boss wave`
  as best-effort.
* **Live inventory counts** are scraped from the game's own Armory screen — open the Armory
  in game once for the Inventory tab to populate. Without it you still get the full static
  catalog.
* **`create_play_session` is gated by unlock state.** The game refuses worlds/modes you
  haven't earned (`difficulty_locked`, `world_locked`, `not_creatable`).
* **Trading off cheat safety:** the hub never touches the game's own module state, so it
  won't trip simple anticheat, but nothing here is undetectable by design.
