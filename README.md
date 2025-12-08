# Cyberpunk 2077: Context-Aware Generative Texting

This project creates a bridge between **Cyberpunk 2077's internal game state** (Redscript engine) and **Large Language Models** (LLMs). While standard generative mods allow for generic conversation, this system injects real-time, high-fidelity context—Quest Objectives, Police Heat Levels, and Weather Conditions—into the LLM's system prompt, allowing companions to react dynamically to the player's immediate reality.
(all the images use OpenAI API)


## The Difference: Context Matters

Standard LLM integration often feels disconnected from gameplay. This system fixes that by injecting the player's active Quest and current Objective into the prompt pipeline.

| **Standard Generative AI** | **Context-Aware System** |
| :---: | :---: |
| ![No Context](Images/NoContextMessage.png)<br>Witout quest context the character seems unaware of the world. | ![With Context](Images/WithContextMessage.png)<br>With the quest "Riders on the Storm" being tracked the character knows the current state of the world. |


## Features & Event Systems

### 1. Dynamic "Heat" Reactivity
The system hooks into the `PreventionSystem` to detect changes in police pursuit levels. It calculates a probability curve based on the threat level (1 Star = Low probability, 5 Stars = 100% probability) to trigger organic reactions.

| **Low Heat (Level 1)** | **Maximum Heat (Level 5)** |
| :---: | :---: |
| ![Heat Level 1](Images/PoliceEventHeatLvl1.png)<br> Casual warning about minor trouble. | ![Heat Level 5](Images/PoliceEventHeatLvl5.png)<br> Urgent, high-stakes reaction. |

To prevent annoyance during minor accidental crimes, the companion's reaction chance scales with the threat level:
  - ★ (1 Star)	20%	Low probability. Minor trouble is often ignored.
  - ★★ (2 Stars)	40%	Moderate probability.
  - ★★★ (3 Stars)	70%	High probability. The situation is getting serious.
  - ★★★★ (4 Stars)	90%	Very High probability.
  - ★★★★★ (5 Stars)	100%	Guaranteed Reaction. MaxTac is involved; the situation is critical.


### 2. Environmental Awareness (Weather Monitor)
Using a custom **Polling Monitor Pattern** (to bypass native API limitations), the system tracks changes in `worldRainIntensity`.
* **Light Rain:** Triggers low-priority warnings.
* **Heavy Rain:** Triggers comments on visibility and driving safety.

![Weather Event](Images/WeatherEventMessage.png)
<br>Companion reacting to a sudden weather shift.<br>

Companions will comment on visibility or toxicity, but not every time it sprinkles:
  - Light Rain: 25% Chance to comment.
  - Heavy Storms: 75% Chance to comment (High Priority).

### 3. Location-Based Invitations (Player Location)
The system tracks V's movement across Night City districts. If you enter a district containing a key location (like a bar associated with a companion), there is a chance they will invite you out. This makes the city feel lived-in and social.
By hooking to the `PreventionSystem` like the Heat Event,but hooked into `OnDistrictAreaEntered`. Companions will invite you to a bar with a 5% chance.

| **Dark Matter Bar** | **Lizzie's Bar** |
| :---: | :---: |
| ![Dark Matter](Images/BarInvitationDarkMatter.png)<br> Companion inviting you to the VIP club. | ![Lizzie's Bar](Images/BarInvitationLizzies.png)<br> Companion noticing you are in Kabuki and inviting you to Lizzie's. |

## Agentic Actions (Money Transfer)

### The Instruction (System Prompt)

We first teach the LLM that it has "tools" available via the System Prompt. We define rigid command tags that the AI must output if it intends to perform an action.

```
[CAPABILITIES: You have access to your bank account. If V asks for money and you agree to help, you can transfer funds.]
[COMMANDS: To send money, output one of these exact tags in your message:]
[ACTION: TRANSFER_100] (For small amounts/lunch)
[ACTION: TRANSFER_1000] (For gear/ammo)
[ACTION: TRANSFER_5000] (For vehicles/major help - Rare!)
[RULE: Do not just say you sent it. You MUST include the tag.]
```

When the response arrives, the HandleMessage function scans the raw string for these specific tags before the text is displayed to the UI. If a tag is found, the associated logic is triggered, and the tag is stripped from the string so the player never sees the "code" behind the magic. And then based on the tag the function to add eddies/creddits is called from the ContextEventManager.reds


![Money Transfer Event](Images/MoneyTransferEven.png)
<br>Asking for some eddies for luch (eddies will be added when exiting PhoneUI - In this case its for luch, so only 100 eddies are added.) <br>




## Under the Hood: Prompt Engineering

To ensure the LLM adheres to the game's narrative, I engineered structured prompt templates that update dynamically based on game state.

### The "Quest Context" Template
This logic resides in `ContextDataSystem.reds`. It maps raw quest titles to narrative summaries to ensure the AI understands the *stakes*, not just the objective.

```text
MISSION: Riders on the Storm. CONTEXT: My leader, Saul, has been kidnapped by the Wraiths.They are holding him at their camp in Sierra Sonora.
We are currently in the middle of a rescue operation.I am terrified of losing him but trying to stay focused.
There is a dust storm approaching which gives us cover but adds urgency.
CURRENT SITUATION: We are currently:Meet with Panam.React to V based on this specific situation.
```

### The "Weather Event" Template
```text
[SYSTEM EVENT: [ENVIRONMENT EVENT: Heavy storm or hazardous rain detected. Low visibility. Warn V to drive carefully.]] V: *System Update* 
```

### The "Police Event" Template
```text
[INSTRUCTION: You are roleplaying. V just gained police heat. Send V a text message reacting to this.DO NOT output the heat level. DO NOT output your mood. DO NOT output your name. Output ONLY the text message body.
Context: "Heat 1 – Mild concern. A light, cautious reaction. You notice the trouble but stay composed.Tone: wary, slightly annoyed, or amused, depending on your personality.
```

### The "District Event" Template
```text
[INSTRUCTION: You are roleplaying. V has just entered the district where you where there is a bar.Send V a casual text message inviting them to join you or if they want to hangout in the future for a drink at the bar. Keep it short and natural. Output location name in your setence for V to know where to meet. Output ONLY the text message body.
Context: Location: Lizzie's Bar (The Mox hangout). Atmosphere: Neon, chaotic, loud braindance music. Tone: Energetic, fun, or cheeky. Mention the vibe.
```

## Core Systems
ContextDataSystem (Passive Data Layer):
  - Responsible for extracting raw data (Quest Title, Weather Enum, Heat Int).
  - Formats raw data into human-readable Prompt Snippets.
  - Contains the "Hardcoded Mapper" for Quest Context to ensure 100% narrative consistency on key missions.

ContextEventManager (Active Logic Layer):
  - Weather Monitor: Implements a resource-efficient 5-second polling loop to detect weather changes (adapting to the lack of a public RegisterListener API).
  - Safety Lock (IsPlayerBusy): Checks scene_tier and is_in_dialogue flags. If V is in a cutscene, incoming messages are snoozed  ensuring the mod never interrupts narrative moments.

GenerativeTextingHttpRequests (Network Layer):
  - Handles the async API calls to OpenAI/Stable Horde.
  - Injects the pendingContext payload generated by the Event Manager.

## OpenRouter Support Added 

Now you can use this mod with the OpenRouter API (https://openrouter.ai/).
Configure the api and model in the GenerativeTextingUtilities.reds


## Credits
- Original Mod: https://www.nexusmods.com/cyberpunk2077/mods/17922 (Used as the base for UI/HTTP handling).
- Extension Author: [Hugo Ferreira] - Implemented Context Systems, Event Listeners, and Narrative Logic, OpenRouter Support.

