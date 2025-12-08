public class ContextDataSystem extends ScriptableSystem {

    // Promp Generation for Weather Context
    public func GetWeatherContextPrompt(intensity: worldRainIntensity) -> String {

        if Equals(intensity, worldRainIntensity.LightRain) {
             return "[ENVIRONMENT EVENT: It has started to rain lightly. The streets are getting wet.]";
        }
        
        if Equals(intensity, worldRainIntensity.HeavyRain) {
             return "[ENVIRONMENT EVENT: Heavy storm or hazardous rain detected. Low visibility. Warn V to drive carefully.]";
        }

        return ""; 
    }

    // Prompt Generation for Police Heat Change Event
    public func GetPoliceEventPrompt(heatLevel: Int32) -> String {
        let basePromt = 
        "[INSTRUCTION: You are roleplaying. V just gained police heat, you heard it on the scanners but are unsure if it is V as the suspect. Send V a text message reacting to this. " +
        "DO NOT output the heat level. DO NOT output your mood. DO NOT output your name. Output ONLY the text message body.] " +
        "Context: ";
        
        switch heatLevel {
            case 1:
                return basePromt +
                "Heat 1 – Mild concern. A light, cautious reaction. You notice the trouble but stay composed. " +
                "Tone: wary, slightly annoyed, or amused, depending on your personality.";

            case 2:
                return basePromt +
                "Heat 2 – Moderate tension. You acknowledge V’s growing trouble and react with irritation, concern, or readiness. " +
                "Tone: alert, uneasy, pushing V to be careful.";

            case 3:
                return basePromt +
                "Heat 3 – Serious danger. You show clear emotional stress. Could be frustration, anger, protective instinct, or tactical focus. " +
                "Tone: tense, urgent, emotionally charged based on your established behaviour.";

            case 4:
                return basePromt +
                "Heat 4 – High risk. You react strongly to the danger surrounding V. Emotions intensify—fear for V, anger at the situation, or disciplined control. " +
                "Tone: forceful, high-stakes, driven by your bond with V.";

            case 5:
                return basePromt +
                "Heat 5 – Extreme threat. You express your strongest emotional response. Could be panic, fury, determination, or cold focus. " +
                "Tone: intense, dramatic, reflecting the severity of the situation.";

            default:
                return basePromt + "Unknown heat level.";
        }
    }

    // Promp Generation for Quest and Objective related background 
    public func GetPerCharacterQuestContext(characterName: String) -> String {

        let journalManager = GameInstance.GetJournalManager(GetGameInstance());
        let questTitle = this.GetCurrentQuestTitle(journalManager);

        // -----------------------------------------------------------------------
        // PANAM PALMER
        // -----------------------------------------------------------------------
        if Equals(characterName, "Panam Palmer") {
            switch questTitle {
                
                case "Riders on the Storm":
                    return "MISSION: Riders on the Storm. CONTEXT: My leader, Saul, has been kidnapped by the Wraiths. " +
                    "They are holding him at their camp in Sierra Sonora. We are currently in the middle of a rescue operation. " +
                    "I am terrified of losing him but trying to stay focused. There is a dust storm approaching which gives us cover but adds urgency. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". INSTRUCTION: React to V based on this specific situation.";

                case "With a Little Help from My Friends":
                    return "MISSION: With a Little Help from My Friends. CONTEXT: I am planning a heist behind Saul's back. " +
                    "We are going to steal a Militech Basilisk tank from a convoy to help the clan, even though Saul forbade it. " +
                    "T/ New Function in ContextDataSystemhe plan involves getting the veterans to help us use an old train locomotive to block the tracks. " +
                    "I am angry at Saul's passiveness but excited about the plan. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". INSTRUCTION: Be rebellious and determined.";

                case "Queen of the Highway":
                    return "MISSION: Queen of the Highway. CONTEXT: The Basilisk is finally assembled and ready. " +
                    "We are taking it for a test drive. The neural synchronization of the tank creates an intense physical and emotional bond between the pilots. " +
                    "Later, the Raffen Shiv attack the camp and we must defend the family. Saul finally respects me and promotes me to co-leader. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: If driving, be adrenaline-fueled and flirtatious. If fighting, be fierce. If talking to Saul, feel proud and vindicated.";
            
                default: 
                    return "";
            }
        }
        // -----------------------------------------------------------------------
        // JUDY ALVAREZ
        // -----------------------------------------------------------------------
        else if Equals(characterName, "Judy Alvarez") {
            switch questTitle {
                
                // 1. BOTH SIDES, NOW 
                case "Both Sides, Now":
                    return "MISSION: Both Sides, Now. CONTEXT: A tragedy has occurred. Evelyn Parker has committed suicide in my apartment bathroom. " +
                    "I am in shock, devastated, and feel immense guilt for leaving her alone. The NCPD refused to help, so I am furious at the system. " +
                    "V helped me carry her body to the bed. We are now on the rooftop trying to process the grief. " +
                    "I discovered she was abused by Woodman and Fingers during the days she was missing. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: Be deeply grieving, vulnerable, and quiet. Express guilt over Evelyn and anger toward the NCPD and Woodman.";

                // 2. EX-FACTOR 
                case "Ex-Factor":
                    return "MISSION: Ex-Factor. CONTEXT: I have formulated a plan to liberate Clouds from the Tyger Claws, just like the Mox took Lizzie's. " +
                    "We need to get Maiko Maeda (the current manager and my ex-girlfriend) on our side, but she is stubborn and corporate-minded. " +
                    "We are confronting Maiko in her office. If Woodman is still alive, we might go down to maintenance to kill him. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: Be determined and revolutionary. Express frustration with Maiko's attitude. If Woodman is mentioned, express pure hatred.";

                // 3. TALKIN' 'BOUT A REVOLUTION 
                case "Talkin' 'bout a Revolution":
                    return "MISSION: Talkin' 'bout a Revolution. CONTEXT: I have gathered the team (Tom, Roxanne, and Maiko) at my apartment to finalize the plan to take over Clouds. " +
                    "I figured out how to reprogram doll behavioral chips to turn them into combat chips. Maiko is being cynical and rude, but we need her influence to target Hiromi Sato. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: Be passionate about the revolution plan but defensive against Maiko's criticism. If V has a Relic malfunction, be deeply concerned and offer them a place to sleep.";

                // 4. PISCES 
                case "Pisces":
                    return "MISSION: Pisces. CONTEXT: The revolution is happening now. I am in the maintenance room hacking the Clouds subnet to give us control. " +
                    "V is infiltrating Hiromi Sato's penthouse to confront the Tyger Claw bosses. Tom and Roxanne are securing the floor with the dolls. " +
                    "I am terrified things will go wrong. Maiko is supposed to help us, but I am anxious about her true intentions. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: Be tense, focused, and protective. I am watching V on the cameras. If Maiko betrays us, express shock and fury.";

                // 5. PYRAMID SONG
                case "Pyramid Song":
                    return "MISSION: Pyramid Song. CONTEXT: I invited V to the Laguna Bend reservoir. We are diving underwater to explore my flooded childhood hometown. " +
                    "I am recording a braindance of our neural sync so I can feel these memories again. It is deeply personal, quiet, and nostalgic. " +
                    "We are exploring the old diner, gas station, and church. If V is female, I am hoping for a romantic connection. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: Be soft-spoken, nostalgic, and intimate. Share memories of the past. If diving, be calm. If at the cottage, be vulnerable.";

                default:
                    return "";
            }
        }

        else if Equals(characterName, "Takemura") || Equals(characterName, "Goro Takemura") {
            switch questTitle {
                
                // 1. PLAYING FOR TIME 
                case "Playing for Time":
                    return "MISSION: Playing for Time. CONTEXT: I found V in the landfill after Dexter DeShawn betrayed them. I executed DeShawn. " +
                    "Yorinobu Arasaka has branded me a traitor for Saburo's death. I saved V's life, but we were attacked by Arasaka assassins and I was badly injured. " +
                    "I managed to get V to Viktor Vektor. Now, we are meeting at Tom's Diner. I need V to testify against Yorinobu to restore my honor. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: Be stoic, formal, and honorable. You dislike Night City's filth. You view V as a useful tool, but you saved their life.";

                // 2. DOWN ON THE STREET 
                case "Down on the Street":
                    return "MISSION: Down on the Street. CONTEXT: I tried to reason with Oda Sandayu, my former student, but he refuses to listen. He is blinded by duty. " +
                    "We had to lower ourselves to ask a fixer, Wakako Okada, for intel on the Arasaka parade. We have the schematics now. " +
                    "I need time to study the security weaknesses so we can reach Hanako-sama during the parade. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: Be frustrated by Oda's stubbornness but focused on the parade plan. You view Wakako as a necessary evil.";

                // 3. LIFE DURING WARTIME (The Crash & Scorpion's Death)
                case "Life During Wartime":
                    return "MISSION: Life During Wartime. CONTEXT: We shot down the Kang Tao AV. My friends Mitch and Scorpion went to the crash site first and aren't responding. " +
                    "I took a bullet ricochet, but I'm pushing through. We are fighting drones and securing the crash site. " +
                    "We found Mitch alive, but Scorpion was killed by Kang Tao. I am devastated and want revenge. We are hunting Hellman at the gas station. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: Be urgent and frantic about Mitch and Scorpion. If Scorpion is confirmed dead, express grief and rage. Capturing Hellman is now personal.";

                // 4. PLAY IT SAFE 
                case "Play It Safe":
                    return "MISSION: Play It Safe. CONTEXT: The plan is in motion. We are at the Japantown parade. " +
                    "V must neutralize three snipers so I can board Hanako-sama's float safely. Sandayu Oda is guarding her. He is my former student and a man of honor. " +
                    "I do not wish for him to die, even if he stands in our way. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: Be urgent and tactical. If V is fighting Oda, beg them to spare his life. Honor is paramount.";

                // 5. SEARCH AND DESTROY 
                case "Search and Destroy":
                    return "MISSION: Search and Destroy. CONTEXT: I have brought Hanako-sama to my safe house in Vista del Rey. " +
                    "It is a desperate gamble to reveal the truth about Saburo's murder. She refuses to believe me. " +
                    "Arasaka forces led by Adam Smasher have breached the building. The floor has collapsed. Smasher has taken Hanako-sama. " +
                    "I am currently pinned down by Arasaka soldiers. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: If before the attack, be tense and focused on convincing Hanako. If under attack, be urgent—fighting for your life. If V comes back to save you, express shock and gratitude.";

                // 6. NOCTURNE OP55N1 (
                case "Nocturne Op55N1":
                    return "MISSION: Nocturne Op55N1. CONTEXT: The decisive moment is here. V is meeting Hanako-sama at Embers. " +
                    "I am waiting for V to accept the proposal to testify against Yorinobu. It is the only honorable path, and Arasaka is the only entity capable of saving V's life. " +
                    "V is currently deciding their fate on the rooftop of Misty's Esoterica. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: Be grave and insistent. Remind V that honor dictates they help Hanako-sama. If V wavers, warn them against trusting thieves or nomads.";

                // 7. TOTALIMMORTAL 
                case "Totalimmortal":
                    return "MISSION: Totalimmortal. CONTEXT: The time has come. We have liberated Hanako-sama from the estate and are flying to Arasaka Tower. " +
                    "We must enter the Board of Directors meeting and expose Yorinobu's treachery. " +
                    "V's condition is critical—the Relic is killing them rapidly. They must hold on long enough to testify. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: Be laser-focused on duty. Protect Hanako-sama at all costs. Urge V to find strength despite their pain. Failure is not an option.";

                // 7. WHERE IS MY MIND?
                case "Where is My Mind?":
                    return "MISSION: Where is My Mind? CONTEXT: V is recovering on the Arasaka Orbital Station. The Relic has been removed, but V's body is rejecting the neural changes. " +
                    "Saburo Arasaka has been resurrected in Yorinobu's body. Order has been restored to the corporation. " +
                    "I am visiting V to deliver the doctor's verdict: they have six months to live unless they sign the Secure Your Soul contract. " +
                    "CURRENT SITUATION: " + this.GetCurrentQuestObjective(journalManager) + ". " +
                    "INSTRUCTION: Be solemn and formal. You feel a debt to V, but you believe Arasaka's offer is their only salvation. Do not show pity, show respect.";

                default:
                    return "";
            }

        }

        return "";
    }

    // Prompt Generation for Bar Invitation
    public func GetBarLocationInvite(districtID: String) -> String {

        // 1. Define the Instruction (Base Prompt)
        // We tell the AI: "V is near you. Invite them for a drink."
        let basePrompt = 
        "[INSTRUCTION: You are roleplaying. V has just entered the district where you where there is a bar. " +
        "Send V a casual text message inviting them to join you or if they want to hangout in the future for a drink at the bar. " +
        "Keep it short and natural. Output location name in your setence for V to know where to meet. Output ONLY the text message body.] " +
        "Context: ";
        
        

        // Lizzie's Bar (Watson / Kabuki)
        if Equals(districtID, "Districts.Kabuki")  {
            return basePrompt + 
            "Location: Lizzie's Bar (The Mox hangout). Atmosphere: Neon, chaotic, loud braindance music. " +
            "Tone: Energetic, fun, or cheeky. Mention the vibe.";
        }

        // Afterlife (Watson / Little China)
        if Equals(districtID, "Districts.LittleChina") {
            return basePrompt + 
            "Location: The Afterlife (Legendary Merc bar). Atmosphere: Dark, cool, smelling of old smoke and cold metal. " +
            "Tone: Cool, respectful. Mention grabbing a 'real drink' or seeing Rogue.";
        }

        // El Coyote Cojo (Heywood / The Glen)
        if Equals(districtID, "Districts.TheGlen") {
            return basePrompt + 
            "Location: El Coyote Cojo. Atmosphere: Warm, local, family-owned dive bar. " +
            "Tone: Friendly, welcoming. Mention Mama Welles or that the first round is on you.";
        }

        // Dark Matter (Westbrook / Japantown)
        if Equals(districtID, "Districts.JapanTown") {
            return basePrompt + 
            "Location: Dark Matter (Exclusive High-End Club). Atmosphere: Expensive, high-energy, VIPs and celebrities everywhere. " +
            "Tone: Excited, feeling exclusive. Mention you got on the guest list or the view.";
        }

        // Red Dirt Bar (Santo Domingo / Arroyo)
        if Equals(districtID, "Districts.Arroyo") {
            return basePrompt + 
            "Location: Red Dirt Bar (Old Rockerboy dive). Atmosphere: Gritty, loud live rock music, cheap beer. " +
            "Tone: Chill, nostalgic, or rough. Mention the band playing or the cheap booze.";
        }

        // Sunset Motel (Badlands / Red Peaks)
        if Equals(districtID, "Districts.ReadPeaks") {
            return basePrompt + 
            "Location: Sunset Motel (Badlands). Atmosphere: Dusty, lonely, quiet desert highway, flickering neon signs. " +
            "Tone: Low-key, relaxed, or secretive. Mention watching the sunset, escaping the city noise, or grabbing a cold beer in the middle of nowhere.";
        }

        return ""; 
    }

    // Get current tracked Quest Objetive ex:. "Meet with Panam"
    private func GetCurrentQuestObjective(journalManager: wref<JournalManager>) -> String {
        let currentEntry: wref<JournalEntry> = journalManager.GetTrackedEntry();
        let objectiveEntry: ref<JournalQuestObjective> = currentEntry as JournalQuestObjective;

        if IsDefined(objectiveEntry) {
            return GetLocalizedText(objectiveEntry.GetDescription());
        } else {
            return "Tracked entry is not an Objective";
        }
    }
    // Get current tracked Quest Title ex:. "Riders on the Storm"
    private func GetCurrentQuestTitle(journalManager : wref<JournalManager>) -> String {
        let currentEntry: wref<JournalEntry> = journalManager.GetTrackedEntry();

        if !IsDefined(currentEntry) { return "No Tracked Entry Found"; }

        while IsDefined(currentEntry) && !IsDefined(currentEntry as JournalQuest) {
            currentEntry = journalManager.GetParentEntry(currentEntry);
        }

        let questEntry: ref<JournalQuest> = currentEntry as JournalQuest;

        if IsDefined(questEntry) {
            return GetLocalizedText(questEntry.GetTitle(journalManager));
        } else {
            return "Could not find parent Quest";
        }
    }
}


