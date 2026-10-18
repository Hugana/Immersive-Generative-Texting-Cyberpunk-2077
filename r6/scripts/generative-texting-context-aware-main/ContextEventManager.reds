public class WeatherMonitorCallback extends DelayCallback {
    public let eventManager: wref<ContextEventManager>;

    //Recursive call to check weather and start another callback
    public func Call() -> Void {
        if IsDefined(this.eventManager) {
            this.eventManager.CheckWeatherChange();
            this.eventManager.CheckTimeEvents();
            this.eventManager.StartWeatherMonitor(); 
        }
    }
}


// Funtion callback to send http request with context
public class ContextEventCallback extends DelayCallback {
    public let contextMessage: String; 
    public let heatLevel: Int32;     
    public let districtName: String;  
    
    public func Call() -> Void {

        let httpSystem = GetHttpRequestSystem();

        if !IsDefined(httpSystem) || !IsDefined(GetTextingSystem()) { return; }

        // Don't fire while loading, in the main menu, or before the player exists
        if GameInstance.GetSystemRequestsHandler().IsPreGame() { return; }
        if !IsDefined(GetPlayer(GetGameInstance())) { return; }

        let eventManager = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"ContextEventManager") as ContextEventManager;

        if IsDefined(eventManager) && eventManager.IsPlayerBusy() { return;}

        if  GetHttpRequestSystem().GetIsGenerating() {return;}

        let lastIndex = ArraySize(httpSystem.npcResponses) - 1;
        if lastIndex >= 0 && Equals(httpSystem.npcResponses[lastIndex],""){
            return;
        }

        httpSystem.pendingContext = this.contextMessage;
        httpSystem.AppendToHistory(GetHiddenMessageMarker(), true);
        httpSystem.AppendToHistory("", false);
        httpSystem.TriggerPostRequest(GetSystemTriggerMessage());
        
        //FTLog("Context Event Triggered: " + this.contextMessage);
    }
}

public static func IsPostHeist(game: GameInstance) -> Bool {
    let qs = GameInstance.GetQuestsSystem(game);
    return
        qs.GetFact(n"q101_started") > 0 ||
        qs.GetFact(n"q005_jackie_to_hospital") > 0 ||
        qs.GetFact(n"q005_jackie_to_mama") > 0 || qs.GetFact(n"q005_done") > 0;
}

public class ContextEventManager extends ScriptableSystem {

    private let lastWeatherType: worldRainIntensity;
    private let hasWeatherBaseline: Bool = false;

    // Time of day events: each window rolls once per in-game day
    private let lastTimeSeconds: Int32;
    private let lastTimeWindowKey: Int32;
    private let skippedSeconds: Int32;
    private let pendingTimeEvent: Int32;
    private let wakeEventChance: Float;
    private let windowEventChance: Float;

    private func OnAttach() -> Void {
        // Weather baseline is taken on the first tick once the player exists,
        // otherwise a save loading into rain reads as a "weather change"
        this.hasWeatherBaseline = false;
        this.lastTimeSeconds = -1;
        this.lastTimeWindowKey = -1;
        this.skippedSeconds = 0;
        this.pendingTimeEvent = -1;
        this.wakeEventChance = 0.5;
        this.windowEventChance = 0.15;

        // Start Loop
        this.StartWeatherMonitor();
        //FTLog("Context Event Manager Attached. Monitoring Weather.");
    }

    // Helper to give money to the player
    public func TransferMoneyToPlayer(amount: Int32) -> Void {
        
        let player = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) { return; }
        let transactionSystem = GameInstance.GetTransactionSystem(this.GetGameInstance());
        let moneyID = ItemID.FromTDBID(t"Items.money");        
        transactionSystem.GiveItem(player, moneyID, amount);

        FTLog("AGENTIC ACTION: Transferred " + amount + " eddies to player.");
    }

    //Check if player is Busy in dialogue or cut-scene
    public func IsPlayerBusy() -> Bool {
       
        let questsSystem = GameInstance.GetQuestsSystem(GetGameInstance());

        let sceneTier = questsSystem.GetFact(n"scene_tier");
        let inDialogue = questsSystem.GetFact(n"is_in_dialogue");

        if (sceneTier > 1) || (inDialogue > 0) {
            return true;
        }

        return false;
    }
    // Function to Start monitorint 
    public func StartWeatherMonitor() -> Void {
        let callback = new WeatherMonitorCallback();
        callback.eventManager = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"ContextEventManager") as ContextEventManager;
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(callback, 5.0, false);
    }

    // Time of day check-ins: morning, late night and after sleeping or skipping time
    public func CheckTimeEvents() -> Void {
        if !IsDefined(GetPlayer(this.GetGameInstance())) { return; }
        if GameInstance.GetSystemRequestsHandler().IsPreGame() { return; }

        let nowSeconds: Int32 = GameInstance.GetGameTime(this.GetGameInstance()).GetSeconds();
        let previousSeconds: Int32 = this.lastTimeSeconds;
        this.lastTimeSeconds = nowSeconds;

        // First reading only sets the baseline so loading a save never counts as a time jump
        if previousSeconds < 0 { return; }

        let day: Int32 = nowSeconds / 86400;
        let hour: Int32 = (nowSeconds % 86400) / 3600;

        // Window ids: 0 = morning, 1 = late night
        let windowId: Int32 = -1;
        if hour >= 6 && hour < 9 {
            windowId = 0;
        } else if hour >= 1 && hour < 4 {
            windowId = 1;
        }

        let windowKey: Int32 = -1;
        let newWindow: Bool = false;
        if windowId >= 0 {
            windowKey = day * 10 + windowId;
            newWindow = windowKey != this.lastTimeWindowKey;
            this.lastTimeWindowKey = windowKey;
        }

        // Sleeping advances the clock fast, possibly over several ticks, so skipped time is added up
        // and the wake event fires once the clock is moving at normal speed again
        let delta: Int32 = nowSeconds - previousSeconds;
        let kind: Int32 = -1;
        if delta >= 1800 {
            this.skippedSeconds += delta;
        } else {
            if this.skippedSeconds >= 7200 {
                kind = 2;
                FTLog("Time event: sleep or time skip detected (" + this.skippedSeconds + " game seconds)");
            }
            this.skippedSeconds = 0;
        }

        if kind < 0 && newWindow {
            kind = windowId;
        }

        // A window is consumed even when the roll fails, so each one rolls once per day
        if kind >= 0 {
            let chance: Float = this.windowEventChance;
            if kind == 2 { chance = this.wakeEventChance; }
            let roll: Float = RandRangeF(0.0, 1.0);
            if roll <= chance {
                this.pendingTimeEvent = kind;
                FTLog("Time event queued: " + kind);
            }
        }

        // Keep the event pending while V is in a scene or dialogue, such as the sleep transition
        if this.pendingTimeEvent < 0 || this.IsPlayerBusy() { return; }

        let dataSystem = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"ContextDataSystem") as ContextDataSystem;
        if !IsDefined(dataSystem) { return; }

        let prompt: String = dataSystem.GetTimeContextPrompt(this.pendingTimeEvent);
        this.pendingTimeEvent = -1;
        if StrLen(prompt) == 0 { return; }

        let eventCallback = new ContextEventCallback();
        eventCallback.contextMessage = prompt;
        eventCallback.heatLevel = 0;
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(eventCallback, 1.0, false);
    }

    //Check weather change
    public func CheckWeatherChange() -> Void {
        if !IsDefined(GetPlayer(this.GetGameInstance())) { return; }

        let weatherSystem = GameInstance.GetWeatherSystem(this.GetGameInstance());
        if !IsDefined(weatherSystem) { return; }
        let currentType = weatherSystem.GetRainIntensityType();

        if !this.hasWeatherBaseline {
            this.lastWeatherType = currentType;
            this.hasWeatherBaseline = true;
            return;
        }

        if NotEquals(currentType, this.lastWeatherType) {
            this.lastWeatherType = currentType;
            //FTLog("Weather Changed: " + ToString(currentType));

            let dataSystem = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"ContextDataSystem") as ContextDataSystem;
            let prompt = dataSystem.GetWeatherContextPrompt(currentType);

            if StrLen(prompt) > 0 {

                let chance: Float = 0.0;

                if Equals(currentType, worldRainIntensity.HeavyRain) {
                    chance = 0.75; // 75% 
                } 
                else if Equals(currentType, worldRainIntensity.LightRain) {
                    chance = 0.25; // 25% 
                }

                let roll: Float = RandRangeF(0.0, 1.0);

                if roll <= chance {
                    
                    let eventCallback = new ContextEventCallback();
                    eventCallback.contextMessage = prompt;
                    eventCallback.heatLevel = 0;
                    
                    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(eventCallback, 1.0, false);
                    
                    //FTLog("Weather Event TRIGGERED: " + ToString(currentType) + " (Rolled: " + roll + ")");
                } else {
                    //FTLog("Weather Event SKIPPED (RNG): " + ToString(currentType) + " (Rolled: " + roll + ")");
                }
            }
        }
    }
}


// Wrapped Method for District Change
@wrapMethod(PreventionSystem)
private final func OnDistrictAreaEntered(request: ref<DistrictEnteredEvent>) -> Void {
    wrappedMethod(request);

    if IsDefined(this.m_districtManager) {
        
        // 3. Get the District Object
        let currentDistrict: ref<District> = this.m_districtManager.GetCurrentDistrict();

        if IsDefined(currentDistrict) {
            
            let districtID: TweakDBID = currentDistrict.GetDistrictID();

            let districtName: String = TDBID.ToStringDEBUG(districtID);

            let dataSystem = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"ContextDataSystem") as ContextDataSystem;
            if !IsDefined(dataSystem) { return; }

            //FTLog("DISTRICT CHANGE DETECTED: " + districtName);

            if Equals(dataSystem.GetBarLocationInvite(districtName),""){ return; }

            let chance: Float = 0.05;

            let roll: Float = RandRangeF(0.0, 1.0);

            if roll <= chance {

                let districtEvent = new ContextEventCallback(); 
                districtEvent.districtName = districtName;
                districtEvent.contextMessage = dataSystem.GetBarLocationInvite(districtName);
                GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(districtEvent, 1.0, false);
            }
        }
    }
}



// Wraped Method for Police Heat Change
@wrapMethod(PreventionSystem)
private final func ChangeHeatStage(newHeatStage: EPreventionHeatStage, heatChangeReason: String) -> Void {
    let oldStageInt: Int32 = EnumInt(this.m_heatStage);
    wrappedMethod(newHeatStage, heatChangeReason);
    let newStageInt: Int32 = EnumInt(newHeatStage);

    if oldStageInt != newStageInt && newStageInt > oldStageInt {

        let chance: Float = 0.0;

        switch newStageInt {
            case 1: 
                chance = 0.20; break; // 20% Chance (Low heat, maybe ignore)
            case 2: 
                chance = 0.40; break; // 40% Chance
            case 3: 
                chance = 0.70; break; // 70% Chance (Getting serious)
            case 4: 
                chance = 0.90; break; // 90% Chance (MaxTac territory)
            case 5: 
                chance = 1.00; break; // 100% Chance (Always trigger on 5 stars)
            default: 
                chance = 0.0;
        }

      
        let roll: Float = RandRangeF(0.0, 1.0);

        if roll <= chance {

            let dataSystem = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"ContextDataSystem") as ContextDataSystem;
            if !IsDefined(dataSystem) { return; }

            let policeEvent = new ContextEventCallback(); 
            policeEvent.heatLevel = newStageInt;
            policeEvent.contextMessage = dataSystem.GetPoliceEventPrompt(newStageInt);
                
            GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(policeEvent, 1.0, false);
        }
    }
}
