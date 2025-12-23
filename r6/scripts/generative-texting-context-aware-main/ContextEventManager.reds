public class WeatherMonitorCallback extends DelayCallback {
    public let eventManager: wref<ContextEventManager>;

    //Recursive call to check weather and start another callback
    public func Call() -> Void {
        if IsDefined(this.eventManager) {
            this.eventManager.CheckWeatherChange();
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

        if !IsDefined(httpSystem) { return; }

        let eventManager = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"ContextEventManager") as ContextEventManager;

        if IsDefined(eventManager) && eventManager.IsPlayerBusy() { return;}

        if  GetHttpRequestSystem().GetIsGenerating() {return;}

        let lastIndex = ArraySize(httpSystem.npcResponses) - 1;
        if lastIndex >= 0 && Equals(httpSystem.npcResponses[lastIndex],""){
            return;
        }

        httpSystem.pendingContext = this.contextMessage;
        httpSystem.AppendToHistory("!?", true);
        httpSystem.AppendToHistory("", false);
        httpSystem.TriggerPostRequest("*System Update*");
        
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

    private func OnAttach() -> Void {
        // Initialize Weather State
        let weatherSystem = GameInstance.GetWeatherSystem(this.GetGameInstance());
        this.lastWeatherType = weatherSystem.GetRainIntensityType();
        
        // Start Loop
        this.StartWeatherMonitor();
        //FTLog("Context Event Manager Attached. Monitoring Weather.");
    }

    // Helper to give money to the player
    public func TransferMoneyToPlayer(amount: Int32) -> Void {
        
        let player = GetPlayer(this.GetGameInstance());
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

    //Check weather change
    public func CheckWeatherChange() -> Void {
        let weatherSystem = GameInstance.GetWeatherSystem(this.GetGameInstance());
        let currentType = weatherSystem.GetRainIntensityType();

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
            
            let policeEvent = new ContextEventCallback(); 
            policeEvent.heatLevel = newStageInt;
            policeEvent.contextMessage = dataSystem.GetPoliceEventPrompt(newStageInt);
                
            GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(policeEvent, 1.0, false);
        }
    }
}
