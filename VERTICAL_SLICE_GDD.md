# ArtifactRun — Vertical Slice Game Design Document

**Document status:** Early Draft  
**Version:** 0.1  
**Genre:** Top-down action, exploration, base defense, and logistics  
**Engine:** Godot  
**Target platform:** PC  
**Development scope:** Solo-developed vertical slice

## 1. High Concept

*ArtifactRun* is a top-down action game in which the player works as a mercenary excavating ancient alien ruins for a profit-driven interplanetary corporation.

During the day, the player explores ruins, locates artifacts, expands infrastructure, and constructs defenses. At night, increasingly aggressive creatures emerge and attack the player's excavation operation.

Excavating an artifact takes multiple in-game days. Once recovered, it must be transported by rail from the excavation site to a company-controlled outpost. Transporting alien technology enrages the creatures, turning delivery into a dangerous moving-defense encounter.

The player is paid according to an artifact's rarity, size, historical value, and remaining condition. Earnings can be invested into weapons, armor, defenses, transportation, and permanent technology upgrades. Some artifacts may instead be kept for their unusual abilities, sacrificing immediate income for long-term power.

## 2. Vertical Slice Purpose

The vertical slice will demonstrate the complete core experience in one compact mission.

It is intended to answer the following questions:

- Is exploring the ruin enjoyable?
- Does the day/night cycle meaningfully change player behavior?
- Is constructing a small defensive position satisfying?
- Does automated excavation create useful tension?
- Is defending a moving artifact transport exciting?
- Does artifact damage create understandable financial stakes?
- Does the payout and upgrade loop motivate another mission?

The slice is not intended to demonstrate the complete campaign, solar-system navigation, multiple planets, extensive technology trees, or long-term corporate quota system.

## 3. Player Fantasy

The player should feel like:

- A heavily armed industrial mercenary operating far from safety.
- An explorer uncovering remnants of an incomprehensibly old civilization.
- A field engineer gradually forcing infrastructure deeper into hostile territory.
- A defender making desperate preparations before nightfall.
- A contractor balancing survival, corporate expectations, and personal greed.

The desired tone combines dangerous archaeology, industrial science fiction, corporate exploitation, and escalating alien hostility.

## 4. Design Pillars

### 4.1 Prepare During the Day

Daylight provides relative safety. The player uses this time to explore, collect supplies, establish extraction sites, build defenses, and extend transportation infrastructure.

Daytime is not completely safe, but enemy activity is limited and less coordinated.

### 4.2 Survive the Night

Night causes a major increase in enemy activity. Creatures emerge in waves and attack the player, structures, and active excavation sites.

The player should feel the approaching night as a deadline. Poor preparation should create difficult—but not automatically unwinnable—situations.

### 4.3 Push Deeper

Valuable artifacts are located progressively farther from the outpost. Reaching them requires longer rail lines, additional defensive positions, and more dangerous expeditions.

Every expansion increases both potential profit and logistical vulnerability.

### 4.4 Protect the Payday

An excavated artifact is not valuable until it reaches the company outpost. Transport triggers increased enemy aggression and creates the mission's climactic moving-defense encounter.

Damage sustained by the artifact directly reduces the player's payment.

### 4.5 Profit Versus Power

Most artifacts can be sold, but certain artifacts provide abilities or permanent advantages if retained.

Keeping an artifact makes the player stronger but sacrifices income and may make corporate quotas harder to meet.

## 5. Core Gameplay Loop

1. Receive an excavation contract.
2. Select weapons and equipment.
3. Enter the excavation zone through the company outpost.
4. Explore the surrounding ruins.
5. Locate an artifact or dig pile.
6. Establish an excavation site.
7. Build defenses and connect supporting infrastructure.
8. Survive while automated excavation progresses.
9. Prepare a rail route to the outpost.
10. Load the artifact onto a transport cart.
11. Defend the artifact during transport.
12. Deliver the artifact and calculate its payout.
13. Purchase an upgrade.
14. Complete or continue the mission.

## 6. Vertical Slice Mission

### 6.1 Mission Summary

The player is sent to a recently discovered alien excavation zone. The company requires the recovery of one large artifact from inside the ruins.

The mission begins during mid-morning at a small company outpost. The artifact is located far enough away that the player must survive one night before excavation can be completed.

### 6.2 Expected Duration

The complete slice should take approximately 30–45 minutes on a successful first attempt.

### 6.3 Mission Sequence

#### Arrival

- Player begins at the outpost.
- A company representative provides a short contract briefing.
- The player selects two weapons from a limited armory.
- Basic construction supplies are provided.

#### Exploration

- The player leaves the outpost and explores a bounded ruin complex.
- Minor enemies and environmental hazards introduce combat.
- Optional supplies can be discovered at small points of interest.
- The required artifact excavation site is marked after discovery.

#### Establishment

- The player places an automated extractor at the dig site.
- Excavation begins and requires approximately two in-game days.
- The player builds walls, turrets, and other defenses.
- A preliminary rail route is extended toward the outpost.

#### First Night

- Enemy activity escalates at nightfall.
- Enemies attack the player, extractor, and nearby defenses.
- The extractor pauses if disabled but does not immediately lose all progress.
- Surviving until daylight creates a period of relief and repair.

#### Transport

- Excavation completes during the following day.
- The artifact is loaded onto a rail cart.
- The player initiates transport manually.
- Artifact transport dramatically raises the local threat level.
- Specialized enemies attempt to intercept and damage the artifact.
- The cart stops if the rail is broken or its path is blocked.

#### Resolution

- The mission succeeds when the artifact reaches the outpost.
- Payment is calculated according to artifact condition.
- The player chooses one upgrade.
- The slice concludes with a short company evaluation.

## 7. World Structure

The vertical slice uses one handcrafted, bounded map rather than a procedurally generated or seamless open world.

The map contains:

- One company outpost and cave entrance.
- One primary ruin complex.
- One required artifact excavation site.
- Two or three optional supply locations.
- Several possible defensive chokepoints.
- One dangerous nighttime location containing an optional reward.
- A partially established rail route that the player must complete.

The map should be large enough to encourage preparation but small enough that returning to the outpost does not become tedious.

## 8. Day and Night Cycle

### Day

- Lasts approximately 6–8 minutes.
- Enemy presence is low.
- Small roaming groups can still appear.
- Exploration and construction are encouraged.
- Visibility is high.
- Extraction proceeds normally.

### Night

- Lasts approximately 3–5 minutes.
- Enemy waves target active human infrastructure.
- Stronger enemy variants may appear.
- Visibility is reduced.
- A rare resource or optional artifact appears only at night.
- Exploration remains possible but becomes extremely dangerous.

A visible clock and clear environmental signals must warn the player before nightfall.

## 9. Player Mechanics

### 9.1 Movement

- Eight-directional top-down movement.
- Sprinting consumes stamina.
- Dodging provides brief damage avoidance or rapid repositioning.
- Movement should remain responsive while aiming.

### 9.2 Combat

The player can carry two weapons and switch between them quickly.

Initial weapon options:

- **Rifle:** Reliable medium-range weapon.
- **Shotgun:** Powerful at close range with limited ammunition.
- **Industrial cutter:** Melee weapon that does not consume ammunition.

Combat should focus on positioning, crowd management, and protecting objectives rather than defeating every enemy personally.

### 9.3 Inventory

The vertical slice uses a small slot-based inventory.

The player can carry:

- Ammunition
- Repair materials
- Construction materials
- Consumable medical supplies
- Small artifacts or alien resources

Large artifacts cannot be carried manually and require rail transport.

## 10. Construction and Defenses

Construction uses a tile-aligned placement grid.

Available structures:

### Wall

Blocks movement and redirects enemies. Walls are inexpensive but can be destroyed.

### Basic Turret

Automatically attacks the closest valid enemy within range.

### Disruption Turret

Deals limited damage but slows or briefly stuns enemies.

### Repair Station

Repairs nearby structures slowly while supplied with materials.

### Extractor

Placed on a valid artifact excavation site. It automatically excavates the artifact over time and becomes a major enemy target.

Structures may be repaired manually using resources. Destroyed defenses are not automatically replaced.

## 11. Artifact System

Artifacts are ancient alien objects recovered from ruins or dig piles.

For the vertical slice, artifacts have four relevant properties:

- **Size:** Determines transportation requirements.
- **Rarity:** Modifies base value.
- **Condition:** Reduced when the artifact is damaged.
- **Threat:** Determines how aggressively enemies react to it.

### Payout

A simplified payout formula will be used:

`Final payout = Base value × Rarity modifier × Remaining condition`

Historical importance may be presented in the artifact's description but does not need a separate mechanical calculation during the slice.

### Keeping an Artifact

The optional nighttime artifact can either be:

- Sold for additional money.
- Retained to unlock a special player ability or passive benefit.

The required mission artifact must be delivered to satisfy the contract.

## 12. Extraction

An extractor progresses automatically after being placed on a valid site.

Extraction rules:

- Progress is measured continuously across the day/night cycle.
- Damage can temporarily disable the extractor.
- Disabled extractors stop progressing until repaired.
- Destroying the extractor does not destroy the buried artifact.
- The player can rebuild the extractor at an additional material cost.
- Enemies become increasingly interested in the site as excavation nears completion.

This allows extraction to create pressure without making a single defensive mistake immediately end the mission.

## 13. Rail Transportation

Rail is the only way to transport large artifacts.

For the vertical slice:

- Rail is placed on a grid.
- Track must form one continuous route to the outpost.
- The system supports straight segments and simple corners.
- The cart follows the validated track automatically.
- The player controls when transport begins.
- Damaged track can stop the cart.
- The player can repair track and resume transport.
- The artifact can be damaged independently of the cart.

Transporting the artifact produces a large threat increase. Enemies may prioritize:

1. The artifact
2. The transport cart or rail
3. The player
4. Nearby defensive structures

The transport sequence should be the mission's most intense encounter.

## 14. Enemies

The vertical slice contains three enemy archetypes.

### Stalker

- Fast, common melee creature.
- Primarily attacks the player.
- Appears during both day and night.

### Breaker

- Slow, durable creature.
- Prioritizes walls, extractors, and turrets.
- Appears primarily during nighttime waves.

### Scavenger

- Fast and relatively fragile.
- Prioritizes exposed artifacts and the transport cart.
- Becomes common during artifact transport.

Enemies use straightforward target-selection rules. Complex group tactics and generalized behavior trees are outside the vertical slice.

## 15. Threat and Aggression

The game maintains a global threat value for the active excavation zone.

Threat increases from:

- Starting an excavation.
- Approaching excavation completion.
- Constructing more infrastructure.
- Transporting an artifact.
- Transporting a rare or high-threat artifact.
- Remaining active during the night.

Threat decreases gradually during daylight when no artifact is being transported.

Threat controls:

- Enemy spawn frequency.
- Wave size.
- Enemy composition.
- Probability of attacks against distant infrastructure.

The vertical slice does not need a highly adaptive AI director. A predictable set of threat thresholds is sufficient.

## 16. Mission Success and Failure

### Full Success

The required artifact reaches the company outpost in good condition.

### Partial Success

The artifact reaches the outpost heavily damaged, producing a reduced payout.

Future missions may support several required artifacts, but the vertical slice contains only one.

### Failure

The mission fails if:

- The required artifact is destroyed.
- The player abandons the contract.
- A future contract deadline expires.

Player death does not immediately destroy the mission.

### Player Death

The corporation reconstructs or replaces the player at the outpost the following morning.

Consequences include:

- One in-game day passes.
- Carried resources are dropped at the death location.
- A reconstruction fee is deducted from the final payout.
- Structures and objectives remain in the world and may be damaged during the time skip.

This system supports the corporate tone without erasing an entire mission's construction progress.

## 17. Economy and Upgrades

After completing the mission, the player receives payment based on:

- Contract completion.
- Artifact condition.
- Optional artifacts recovered.
- Reconstruction or equipment fees.

The slice offers one upgrade choice from a limited list:

- Increased maximum health.
- Increased weapon damage.
- Faster extraction.
- Stronger turret damage.
- Increased artifact-cart durability.

The complete technology tree, prerequisites, quotas, debt, and repossession systems are deferred.

## 18. Presentation

### Visual Direction

- Industrial human equipment contrasted against ancient alien architecture.
- Human structures should look temporary, modular, and utilitarian.
- Alien ruins should appear massive, old, and poorly understood.
- Night should alter visibility without making the game unreadable.
- Artifact transport should produce strong visual and audio feedback.

### Audio Direction

- Sparse ambient sound during exploration.
- Machinery and extractor noise communicate human intrusion.
- Warning signals announce approaching nightfall.
- Creature activity becomes louder and more layered at night.
- Artifact transport introduces a distinct high-intensity music state.

## 19. Interface Requirements

The player must always be able to understand:

- Current time and time until nightfall.
- Health and stamina.
- Equipped weapons and ammunition.
- Available construction materials.
- Extractor progress and condition.
- Current threat level.
- Artifact condition.
- Rail connectivity and transport status.
- Mission objective.

The interface should emphasize warnings and actionable information without becoming a general-purpose operating-system interface.

## 20. Out of Scope

The following features will not be part of the initial vertical slice:

- Multiple planets
- Solar-system travel
- Ship customization
- Procedural world generation
- Seamless open world
- Multiple simultaneous contracts
- Weekly quota simulation
- Equipment repossession
- Large technology trees
- Multiplayer
- Extensive crafting
- Custom scripting language
- Custom map editor
- General-purpose ECS
- In-game terminal

## 21. Vertical Slice Completion Criteria

The slice is complete when:

- A new player can finish the mission without developer assistance.
- The entire core loop works from arrival through payout.
- Day and night require observably different strategies.
- Building defenses improves survival.
- Artifact transport creates a noticeable combat climax.
- Artifact damage affects the final payout.
- At least one upgrade changes subsequent gameplay.
- The game can be restarted without editor intervention.
- There are no progression-blocking bugs during a normal playthrough.

## 22. Open Design Questions

These decisions should be resolved through prototypes and playtesting:

- Can enemies permanently destroy rail, or only disable it?
- Can the cart reverse to safety?
- Does ammunition regenerate, require crafting, or come from supply drops?
- Can the player operate more than one extractor simultaneously?
- Should extraction continue while the player is far away?
- How much control does the player have over turret targeting?
- Can optional artifacts be carried, or do all artifacts require transport?
- Does death advance time automatically or trigger a playable recovery event?
- How visible should the numeric threat value be?
- Is the optional nighttime reward powerful enough to justify leaving the base?
- Can the company detect when the player secretly retains an artifact?

The next document revision should lock down the moment-to-moment combat model, construction rules, rail behavior, and a concrete map layout. Those systems are the most likely to determine whether the central loop feels good.
