import Codeware.*
import RedData.Json.*
import RedHttpClient.*
import RedFileSystem.*


public class HttpRequestSystem extends ScriptableSystem {
  private let m_callbackSystem: wref<CallbackSystem>;
  private let generationId: String;
  private let playerInput: String;
  private let timeArray: array<String>;
  private let isGenerating: Bool = false;
  private let noWorkers: Bool = false;
  private let getAttempt: Int32 = 0;
  private let phoneController: wref<NewHudPhoneGameController>;
  private let systemPrompt: String;
  private let systemPromptRomance: String;
  public let vMessages: array<String>;
  public let npcResponses: array<String>;

  // added for game contex.
  public let pendingContext: String; 

  /// Lifecycle ///

  private func OnAttach() {
    this.m_callbackSystem = GameInstance.GetCallbackSystem();
    this.m_callbackSystem.RegisterCallback(n"Session/Ready", this, n"OnSessionReady");
  }

  private func OnDetach() {
    this.m_callbackSystem.UnregisterCallback(n"Session/Ready", this, n"OnSessionReady");
    this.m_callbackSystem = null;
  }

  /// Game events ///

  private cb func OnSessionReady(event: ref<GameSessionEvent>) {
    let isPreGame = event.IsPreGame();
    if !isPreGame {
      return;
    }
  }

  // Post request
  public func TriggerPostRequest(playerMessage: String) {
    this.playerInput = playerMessage;
    let aiModel = GetTextingSystem().aiModel;
    switch aiModel {
      case LLMProvider.StableHorde:
        this.StableHordePostRequest(playerMessage);
        break;
      case LLMProvider.OpenAI:
        this.OpenAiPostRequest(playerMessage);
        break;
      case LLMProvider.OpenRouter:    
        this.OpenRouterPostRequest(playerMessage);
        break;
    }
  }

  //OperRouter Post Request
  private func OpenRouterPostRequest(playerMessage: String) {

    let apiKey = GetOpenRouterApiKey(); 

    if Equals(apiKey, "0000000000") || StrLen(apiKey) < 10 {
      ConsoleLog("OpenRouter API key not set.");
      this.HandleMessage("[SYSTEM ERROR: Please enter a valid OpenRouter Key in Mod Settings]");
      return;
    }

    let requestDTO = this.BuildOpenRouterMessages(playerMessage);
    let jsonRequest = ToJson(requestDTO);
    
    let callback = HttpCallback.Create(this, n"OnOpenAIResponse");
   
    let headers: array<HttpHeader> = [
        HttpHeader.Create("Content-Type", "application/json"),
        HttpHeader.Create("Authorization", "Bearer " + apiKey),
        HttpHeader.Create("HTTP-Referer", "https://github.com/Hugana/generative-texting-context-aware/tree/main"), 
        HttpHeader.Create("X-Title", "Cyberpunk GenText Mod")
    ];

    AsyncHttpClient.Post(callback, "https://openrouter.ai/api/v1/chat/completions", jsonRequest.ToString(), headers);
    
    ConsoleLog("== OpenRouterPOST Request ==");
    ConsoleLog(s"\(jsonRequest.ToString("\t"))");
    this.ToggleIsGenerating(true);
  }

  // Stable Horde Post Request
  private func StableHordePostRequest(playerMessage: String) {
    let requestDTO = this.CreateTextGenerationRequest(playerMessage);
    let tokens = this.EstimateTokens(requestDTO.prompt);
    let jsonRequest = ToJson(requestDTO);
    
    let callback = HttpCallback.Create(this, n"StableHordePostResponse");
    let headers: array<HttpHeader> = [
        HttpHeader.Create("Content-Type", "application/json"),
        HttpHeader.Create("accept", "application/json"),
        HttpHeader.Create("apikey", GetOpenRouterApiKey()),
        HttpHeader.Create("Client-Agent", "unknown:0:unknown")
    ];
    
    AsyncHttpClient.Post(callback, "https://stablehorde.net/api/v2/generate/text/async", jsonRequest.ToString(), headers);
    ConsoleLog("== API POST Request ==");
    ConsoleLog(s"\(jsonRequest.ToString("\t"))");
    ConsoleLog(s"== Tokens: \(tokens) ==");
    this.ToggleIsGenerating(true);
  }

  // OpenAI Post Request
  private func OpenAiPostRequest(playerMessage: String) {
    if Equals (GetOpenAiApiKey(), "0000000000") {
      ConsoleLog("OpenAI API key not set. Please update your API key in GenerativeTextingUtilities.reds.");
      this.HandleMessage("[ERROR CODE: 5002] - YOUR MESSAGE COULD NOT BE SENT. PLEASE UPDATE YOUR API KEY AND TRY AGAIN.");
      return;
    }

    let requestDTO = this.BuildOpenAIMessages(playerMessage);
    let jsonRequest = ToJson(requestDTO);
    
    let callback = HttpCallback.Create(this, n"OnOpenAIResponse");
    let headers: array<HttpHeader> = [
        HttpHeader.Create("Content-Type", "application/json"),
        HttpHeader.Create("Authorization", "Bearer " + GetOpenAiApiKey())
    ];

    AsyncHttpClient.Post(callback, "https://api.openai.com/v1/chat/completions", jsonRequest.ToString(), headers);
    ConsoleLog("== OpenAI POST Request ==");
    ConsoleLog(s"\(jsonRequest.ToString("\t"))");
    this.ToggleIsGenerating(true);
  }

  // OpenAI Post Response
  private cb func OnOpenAIResponse(response: ref<HttpResponse>) {
    if !Equals(response.GetStatus(), HttpStatus.OK) {
        ConsoleLog(s"Request failed, status code: \(response.GetStatusCode())");
        this.ToggleIsGenerating(false);
        return;
    }

    let json = response.GetJson();
    if json.IsUndefined() {
        ConsoleLog("Failed to parse JSON response");
        this.ToggleIsGenerating(false);
        return;
    }

    ConsoleLog("== OpenAI POST Response ==");
    ConsoleLog(s"\(json.ToString("\t"))");

    let responseObj = json as JsonObject;
    let choices = responseObj.GetKey("choices") as JsonArray;
    let firstChoice = choices.GetItem(0u) as JsonObject;
    let message = firstChoice.GetKey("message") as JsonObject;
    let text = message.GetKeyString("content");

    if (StrLen(text) > 0) {
      this.DelayedTyping();
      this.DelayedMessage(text);
    } else {
        ConsoleLog("No text found in OpenAI response.");
        this.ToggleIsGenerating(false);
    }
  }

  // Stable Horde get request
  public func TriggerGetRequest() {
    ConsoleLog("== API GET Request ==");
    let callback = HttpCallback.Create(this, n"StableHordeGetResponse");
    AsyncHttpClient.Get(callback, "https://stablehorde.net/api/v2/generate/text/status/" + this.generationId);
    this.getAttempt += 1;
    ConsoleLog(s"Sending GET request \(this.getAttempt)...");
  }

  /// Callbacks ///
  private cb func StableHordePostResponse(response: ref<HttpResponse>) {
    ConsoleLog("== API POST Response ==");
    if !Equals(response.GetStatus(), 202) {
        ConsoleLog(s"Request failed, status code: \(response.GetStatusCode())");
        let json = response.GetJson();
        ConsoleLog(s"\(json.ToString("\t"))");
        this.ToggleIsGenerating(false);
        return;
    }
    
    let json = response.GetJson();
    if json.IsUndefined() {
        ConsoleLog("Failed to parse JSON response");
        this.ToggleIsGenerating(false);
        return;
    }

    let responseObj = json as JsonObject;
    this.generationId = responseObj.GetKeyString("id");
    this.noWorkers = IsDefined(responseObj.GetKey("message"));

    ConsoleLog("== JSON POST Response ==");
    ConsoleLog(s"\(json.ToString("\t"))");
    this.DelayedGet();
  }

  private cb func StableHordeGetResponse(response: ref<HttpResponse>) {
    ConsoleLog("== API GET Response ==");
    if !Equals(response.GetStatus(), HttpStatus.OK) {
      ConsoleLog(s"Request failed, status code: \(response.GetStatusCode())");
      if Equals(response.GetStatusCode(), 404) {
        this.FailedToGet();
      }
      return;
    }
    let json = response.GetJson();
    
    if json.IsUndefined() {
      ConsoleLog("Failed to parse JSON response");
      this.ToggleIsGenerating(false);
      return;
    }

    let responseObj = json as JsonObject;
    let status = responseObj.GetKeyInt64("finished");
    if NotEquals(status, 1) {
      ConsoleLog(s"Wait Time: \(responseObj.GetKeyInt64("wait_time"))");
      ConsoleLog(s"Queue Position: \(responseObj.GetKeyInt64("queue_position"))");
      let queuePosition = responseObj.GetKeyUint64("queue_position");
      if (!this.noWorkers && (queuePosition < 30ul)) {
        this.ToggleTypingIndicator(true);
      } 
      if ((this.getAttempt > 20) && this.noWorkers) {
        this.FailedToGet();
        return;
      }
      this.DelayedGet();
      return;
    }

    ConsoleLog(s"\(json.ToString("\t"))");
    
    this.noWorkers = false;
    this.getAttempt = 0;

    let generations = responseObj.GetKey("generations") as JsonArray;
    let item = generations.GetItem(0u) as JsonObject;
    let text = item.GetKeyString("text");
    this.HandleMessage(text);
  }

  private func HandleMessage(text: String) {
    
    let processedText = text;
    
    // Context Event Manager to add Eddies
    let eventManagerMessage = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"ContextEventManager") as ContextEventManager;

    // Parsing the message to and replacing action 
    if StrContains(processedText, "[ACTION:TRANSFER_100]") {
        eventManagerMessage.TransferMoneyToPlayer(100);
        processedText = StrReplace(processedText, "[ACTION:TRANSFER_100]", "");
    }
    
    if StrContains(processedText, "[ACTION:TRANSFER_1000]") {
        eventManagerMessage.TransferMoneyToPlayer(1000);
        processedText = StrReplace(processedText, "[ACTION:TRANSFER_1000]", "");
    }

    if StrContains(processedText, "[ACTION:TRANSFER_5000]") {
        eventManagerMessage.TransferMoneyToPlayer(5000);
        processedText = StrReplace(processedText, "[ACTION:TRANSFER_5000]", "");
    }
    
    // More processing
    processedText = StrReplace(processedText, "  ", " ");

    if StrBeginsWith(processedText, " ") {
      processedText = StrRight(processedText, (StrLen(processedText) - 1));
    }
    
    if GetTextingSystem().GetChatOpen() {
      this.ToggleTypingIndicator(false);
      
      if StrLen(processedText) > 1000 {
        let firstHalf = StrLeft(processedText, 1000);
        let secondHalf = StrRight(processedText, (StrLen(processedText) - 1000));
        this.BuildTextMessage(firstHalf);
        this.BuildTextMessage(secondHalf);
      } else {
        this.BuildTextMessage(processedText);
      }
      GetTextingSystem().UpdateInputUi();
    } else {
      this.PushNotification(processedText); 
    }

    this.AppendToHistory(processedText, false);
    this.ToggleIsGenerating(false);
  }

  // Estimate tokens based on number of words in prompt where 75 words roughly = 100 tokens
  private func EstimateTokens(prompt: String) -> Int32 {
    let words = StrSplit(prompt, " ");
    let tokens = (ArraySize(words) * 133)/100;
    return tokens;
  }

  // Push a notification to the player's HUD
  private func PushNotification(text: String) {
    if !IsDefined(this.phoneController) {
      let inkSystem = GameInstance.GetInkSystem();
      let layers = inkSystem.GetLayers();
      for layer in layers {
        for controller in layer.GetGameControllers() {
          if Equals(s"\(controller.GetClassName())", "NewHudPhoneGameController") {
              this.phoneController = controller as NewHudPhoneGameController;
          }
        }
      }
    }

    this.phoneController.PushCustomSMSNotification(text);
    GetTextingSystem().ToggleUnread(true);
  }

  // Handle failed GET requests
  private func FailedToGet() {
      let text = "[ERROR CODE: 5001 - YOUR MESSAGE COULD NOT BE SENT. PLEASE TRY AGAIN LATER.]";
      this.getAttempt = 0;
      this.ToggleIsGenerating(false);
      this.PushNotification(text);
      this.AppendToHistory(text, false);
  }

  // Delay the GET request
  private func DelayedGet() {
    let delaySystem = GameInstance.GetDelaySystem(GetGameInstance());
    let delay = RandRangeF(4.0, 6.0);
    let isAffectedByTimeDilation: Bool = false;

    delaySystem.DelayCallback(HttpDelayCallback.Create(), delay, isAffectedByTimeDilation);
  }

  private func DelayedTyping() {
    let delaySystem = GameInstance.GetDelaySystem(GetGameInstance());
    let delay = RandRangeF(2.0, 4.0);
    let isAffectedByTimeDilation: Bool = false;

    delaySystem.DelayCallback(TypingDelayCallback.Create(), delay, isAffectedByTimeDilation);
  }

  // Delay message rendering
  private func DelayedMessage(text: String) {
    let delaySystem = GameInstance.GetDelaySystem(GetGameInstance());
    let delay = RandRangeF(5.0, 9.0);
    let isAffectedByTimeDilation: Bool = false;

    delaySystem.DelayCallback(MessageDelayCallback.Create(text), delay, isAffectedByTimeDilation);
  }

  // Build the text message by passing in the text author and whether to play an anim
  private func BuildTextMessage(text: String) {
    if (IsDefined(GetTextingSystem()) && GetTextingSystem().GetChatOpen()) {
      GetTextingSystem().BuildMessage(text, false, true);
    }
  }

  public func ToggleTypingIndicator(value: Bool) {
    if (IsDefined(GetTextingSystem())) {
      GetTextingSystem().ToggleTypingIndicator(value);
    }
  }

  public func GetIsGenerating() -> Bool {
    return this.isGenerating;
  }

  // Add new messages to history arrays
  public func AppendToHistory(message: String, fromPlayer: Bool) {

    //Remove Whitespaces at the start of the message
    while StrBeginsWith(message, "\n") || StrBeginsWith(message, " ") {
        message = StrRight(message, StrLen(message) - 1);
    }

    if fromPlayer {
            let jsonSystem = PersistentStorageService.GetPersistentStorageSystem();

            let m_storage: ref<FileSystemStorage> = jsonSystem.GetFileStorage();

            let file = jsonSystem.GetFileStorage().GetFile("my_config.json");

            let json = file.ReadAsJson();   

            let jsonContent: String = json.ToString("    "); 

            let json = ParseJson(jsonContent) as JsonObject; 
            
            let char:String = GetCharacterContactName(GetTextingSystem().character);

            let characterObject = json.GetKey(char) as JsonObject;

            let resultString: String = characterObject.GetKeyString("vMessages");

            let resultArray: array<String> = StrSplit(resultString, "|");

            let max_messages: Int32 = 20;

            if ArraySize(resultArray) >= max_messages {

                let newString: String = "";
                let count: Int32 = 0;

                for elem in resultArray {
                    count += 1;
                    if count == 1 {
                    
                    }else{
                        newString += elem + "|";
                    }
                }

                newString += message + "|";

                characterObject.SetKeyString("vMessages", newString);

                let file = m_storage.GetFile("my_config.json");  
                
                file.WriteJson(json); 
                
            }else{
                let jsonSystem = PersistentStorageService.GetPersistentStorageSystem();

                let m_storage: ref<FileSystemStorage> = jsonSystem.GetFileStorage();

                let file = jsonSystem.GetFileStorage().GetFile("my_config.json");

                let json = file.ReadAsJson();   

                let jsonContent: String = json.ToString("    "); 

                let json = ParseJson(jsonContent) as JsonObject; 
                
                let char:String = GetCharacterContactName(GetTextingSystem().character);

                let characterObject = json.GetKey(char) as JsonObject;

                let newString: String = characterObject.GetKeyString("vMessages");

                newString += message + "|";

                characterObject.SetKeyString("vMessages", newString);

                let file = m_storage.GetFile("my_config.json");  

                file.WriteJson(json);    
            }

        }
        
        if !fromPlayer{

            let jsonSystem = PersistentStorageService.GetPersistentStorageSystem();

            let m_storage: ref<FileSystemStorage> = jsonSystem.GetFileStorage();

            let file = jsonSystem.GetFileStorage().GetFile("my_config.json");

            let json = file.ReadAsJson();   

            let jsonContent: String = json.ToString("    "); 

            let json = ParseJson(jsonContent) as JsonObject; 
            
            let char:String = GetCharacterContactName(GetTextingSystem().character);

            let characterObject = json.GetKey(char) as JsonObject;

            let resultString: String = characterObject.GetKeyString("npcResponses");

            let resultArray: array<String> = StrSplit(resultString, "|");

            let max_messages: Int32 = 20;

            if ArraySize(resultArray) >= max_messages {

                let newString: String = "";
                let count: Int32 = 0;

                for elem in resultArray {
                    count += 1;
                    if count == 1 {
                    
                    }else{
                        newString += elem + "|";
                    }
                }

                newString += message;

                characterObject.SetKeyString("npcResponses", newString);

                let file = m_storage.GetFile("my_config.json");  
                
                file.WriteJson(json); 
                
            }else{
                let jsonSystem = PersistentStorageService.GetPersistentStorageSystem();

                let m_storage: ref<FileSystemStorage> = jsonSystem.GetFileStorage();

                let file = jsonSystem.GetFileStorage().GetFile("my_config.json");

                let json = file.ReadAsJson();   

                let jsonContent: String = json.ToString("    "); 

                let json = ParseJson(jsonContent) as JsonObject; 
                
                let char:String = GetCharacterContactName(GetTextingSystem().character);

                let characterObject = json.GetKey(char) as JsonObject;

                let newString: String = characterObject.GetKeyString("npcResponses");

                newString += message + "|";

                characterObject.SetKeyString("npcResponses", newString);

                let file = m_storage.GetFile("my_config.json");  

                file.WriteJson(json); 
            }  

        }

    if fromPlayer {
      ArrayPush(this.vMessages, message);
    } else {
      let lastIndex = ArraySize(this.npcResponses) - 1;
      
      //If the message is "" then append message 
      if lastIndex >= 0 && Equals(this.npcResponses[lastIndex], "") {
            
            this.npcResponses[lastIndex] = message;

        } else {
        
            ArrayPush(this.npcResponses, message);
        }
    }

    // Limit history to the last 20 exchanges
    if ArraySize(this.vMessages) > 20 {
      ArrayErase(this.vMessages, 0);
    }
  }

  // Reset the conversation history
  public func ResetConversation() {
    ArrayClear(this.vMessages);
    ArrayClear(this.npcResponses);
  }

  // Undo the last message from the NPC and V
  public func UndoMessage() {
    if ArraySize(this.vMessages) > 0 {
      ArrayPop(this.vMessages);
    }
    if ArraySize(this.npcResponses) > 0 {
      ArrayPop(this.npcResponses);
    }
  }

  // Toggle generation state
  public func ToggleIsGenerating(value: Bool) {
    this.isGenerating = value;
    GetTextingSystem().UpdateInputUi();
  }

  // Generate the prompt using the arrays
  public func GeneratePrompt(playerInput: String) -> String {
    let promptText = this.GetSystemPrompt() + "\n\n";

    // Concatenate recent exchanges to form the conversation history
    let i = 0;
    while i < ArraySize(this.vMessages) {
      promptText = promptText + "V: " + this.vMessages[i] + "\n";
      promptText = promptText + GetCharacterLocalizedName(GetTextingSystem().character) + ": " + this.npcResponses[i] + "\n";
      i += 1;
    }

    /*// Added for game context
    if StrLen(this.pendingContext) > 0 {
        promptText += "\n[SYSTEM EVENT: " + this.pendingContext + "]\n";

        this.pendingContext = ""; 
    }*/

    // Add the player’s current message to the prompt
    promptText += "V: " + playerInput + " <|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n" + GetCharacterLocalizedName(GetTextingSystem().character) + ": ";

    return promptText;
  }

  // Build the system prompt based on the selected character and relationship
  private func GetSystemPrompt() -> String {

    this.systemPrompt = "";

    let character = GetTextingSystem().character;
    let romance = GetTextingSystem().romance;
    let guidelines = GetGuidelines();

    // If the current selected character as a tracked mission: Append the context of the mission to the prompt
    let dataSystem = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"ContextDataSystem") as ContextDataSystem;

    this.systemPrompt += "<|start_header_id|> system: <|end_header_id|>";
    this.systemPrompt += "<system>";
    this.systemPrompt += guidelines;
    this.systemPrompt += "</system>";
    this.systemPrompt += GetConversationType();
    this.systemPrompt += "<character>";
    this.systemPrompt += GetCharacterBio(character);
    this.systemPrompt += "</character>";
    this.systemPrompt += "<mission>";
    this.systemPrompt += dataSystem.GetPerCharacterQuestContext(GetCharacterLocalizedName(character));
    this.systemPrompt += "</mission>";
    this.systemPrompt += "<relationship>";
    this.systemPrompt += GetCharacterRelationship(character, romance);
    this.systemPrompt += "</relationship>";
    this.systemPrompt += "<interactions>";
    this.systemPrompt += GetWorldInteractions();
    this.systemPrompt += "</interactions>";
    this.systemPrompt += "<mechanics>";
    this.systemPrompt += GetWorldMechanics();
    this.systemPrompt += "</mechanics>";
    this.systemPrompt += "<event>";
    this.systemPrompt += this.pendingContext;
    this.systemPrompt += "</event>";
    this.systemPrompt += "<language>";
    this.systemPrompt += GetPlayerLanguage();
    this.systemPrompt += "</language>";
    this.systemPrompt += "<|eot_id>";

    this.pendingContext = "";

    return this.systemPrompt;    
  }

  // Helper to get ONLY conversation history + input (No System Prompt)
  public func GenerateConversationString(playerInput: String) -> String {
    let promptText = ""; 

    // 1. Concatenate History
    let i = 0;
    while i < ArraySize(this.vMessages) {
      promptText += "V: " + this.vMessages[i] + "\n";
      promptText += GetCharacterLocalizedName(GetTextingSystem().character) + ": " + this.npcResponses[i] + "\n";
      i += 1;
    }

    /*// 2. Inject Pending Context (Police/Weather events go here)
    if StrLen(this.pendingContext) > 0 {
        promptText += "\n[SYSTEM EVENT: " + this.pendingContext + "]\n";
        this.pendingContext = ""; 
    }*/

    // 3. Add Player Input
    promptText += "V: " + playerInput + " <|eot_id|><|start_header_id|>character<|end_header_id|>\n\n" + GetCharacterLocalizedName(GetTextingSystem().character) + ": ";

    return promptText;
  }

  // Build the post request
  public func CreateTextGenerationRequest(playerInput: String) -> ref<TextGenerationRequestDTO> {
    let requestDTO = new TextGenerationRequestDTO();
    requestDTO.prompt = this.GeneratePrompt(playerInput);  
    requestDTO.trusted_workers = false;
    /**requestDTO.models = ["aphrodite/Sao10K/L3-8B-Lunaris-v1", "koboldcpp/L3-8B-Stheno-v3.2",
    "koboldcpp/NeuralDaredevil-8B-abliterated"];*/
    
    //For faster response with stable horde
    requestDTO.models = [];

    let paramsDTO = new TextGenerationParamsDTO();
    paramsDTO.gui_settings = false;
    paramsDTO.sampler_order = [6, 0, 1, 2, 3, 4, 5];
    paramsDTO.max_context_length = 8192;
    paramsDTO.max_length = 300;
    paramsDTO.rep_pen = 1.1;
    paramsDTO.rep_pen_range = 600;
    paramsDTO.rep_pen_slope = 0;
    paramsDTO.temperature = GetTextingSystem().temperature;
    paramsDTO.tfs = GetTextingSystem().tfs;
    paramsDTO.top_a =GetTextingSystem().top_a;
    paramsDTO.top_k = GetTextingSystem().top_k;
    paramsDTO.top_p = GetTextingSystem().top_p;
    paramsDTO.min_p = GetTextingSystem().min_p;
    paramsDTO.typical = GetTextingSystem().typical;
    paramsDTO.use_world_info = false;
    paramsDTO.singleline = false;
    paramsDTO.stop_sequence = [
      "\nV:", "<|eot_id|>", 
      "<|start_header_id|>user<|end_header_id|>", 
      "<|start_header_id|>assistant<|end_header_id|>", 
      "<|start_header_id|>system<|end_header_id|>"
    ];
    paramsDTO.streaming = false;
    paramsDTO.can_abort = false;
    paramsDTO.mirostat = 0;
    paramsDTO.mirostat_tau = 5.0;
    paramsDTO.mirostat_eta = 0.1;
    paramsDTO.use_default_badwordsids = false;
    paramsDTO.grammar = "";
    paramsDTO.n = 1;
    paramsDTO.frmtadsnsp = false;
    paramsDTO.frmtrmblln = false;
    paramsDTO.frmtrmspch = false;
    paramsDTO.frmttriminc = false;

    requestDTO.params = paramsDTO;

    return requestDTO;
  }

   private func BuildOpenRouterMessages(playerMessage: String) -> ref<OpenAIRequestDTO> {
    let requestDTO = new OpenAIRequestDTO();
  
    requestDTO.model = GetOpenRouterModel(); 
    let preferredProvider = GetOpenRouterProvider(); 

    if NotEquals(preferredProvider, "Auto") && StrLen(preferredProvider) > 0 {
        
        let providerDTO = new OpenRouterProviderDTO();
        let orderArray: array<String>;
        ArrayPush(orderArray, preferredProvider);
        
        providerDTO.order = orderArray;
        providerDTO.allow_fallbacks = true; 
        requestDTO.provider = providerDTO;
      
        ConsoleLog("OpenRouter: Routing preference set to " + preferredProvider);
    }

    let messagesArray: array<ref<OpenAIMessageDTO>>;

    // 1. System Message (Contains the Instructions)
    let systemMessage = new OpenAIMessageDTO();
    systemMessage.role = "system";
    systemMessage.content = this.GetSystemPrompt(); 
    ArrayPush(messagesArray, systemMessage);

    // 2. User Message (Contains ONLY History + Input)
    let userMessage = new OpenAIMessageDTO();
    userMessage.role = "user";
    
    // FIX: Use the new function so we don't duplicate the prompt
    userMessage.content = this.GenerateConversationString(playerMessage); 
    
    ArrayPush(messagesArray, userMessage);

    requestDTO.messages = messagesArray;
    return requestDTO;
  }

  
  // Change return type to StandardOpenAIRequestDTO
private func BuildOpenAIMessages(playerMessage: String) -> ref<StandardOpenAIRequestDTO> {
    let requestDTO = new StandardOpenAIRequestDTO(); // Use the clean class
    requestDTO.model = "gpt-4o-mini";
    
    let messagesArray: array<ref<OpenAIMessageDTO>>;

    // 1. System Message
    let systemMessage = new OpenAIMessageDTO();
    systemMessage.role = "system";
    systemMessage.content = this.GetSystemPrompt();
    ArrayPush(messagesArray, systemMessage);

    // 2. User Message
    let userMessage = new OpenAIMessageDTO();
    userMessage.role = "user";
    
    // Use GenerateConversationString to avoid duplicating system prompt
    userMessage.content = this.GenerateConversationString(playerMessage);
    
    ArrayPush(messagesArray, userMessage);

    requestDTO.messages = messagesArray;
    return requestDTO;
  }
} 


public class StandardOpenAIRequestDTO {
  public let model: String;
  public let messages: array<ref<OpenAIMessageDTO>>;
}

public class TextGenerationRequestDTO {
    public let prompt: String;
    public let params: ref<TextGenerationParamsDTO>;
    public let trusted_workers: Bool;
    public let models: array<String>;
}

public class TextGenerationParamsDTO {
    public let gui_settings: Bool;
    public let sampler_order: array<Int32>;
    public let max_context_length: Int32;
    public let max_length: Int32;
    public let rep_pen: Float;
    public let rep_pen_range: Int32;
    public let rep_pen_slope: Int32;
    public let temperature: Float;
    public let tfs: Float;
    public let top_a: Float;
    public let top_k: Int32;
    public let top_p: Float;
    public let min_p: Float;
    public let typical: Float;
    public let use_world_info: Bool;
    public let singleline: Bool;
    public let stop_sequence: array<String>;
    public let streaming: Bool;
    public let can_abort: Bool;
    public let mirostat: Int32;
    public let mirostat_tau: Float;
    public let mirostat_eta: Float;
    public let use_default_badwordsids: Bool;
    public let grammar: String;
    public let n: Int32;
    public let frmtadsnsp: Bool;
    public let frmtrmblln: Bool;
    public let frmtrmspch: Bool;
    public let frmttriminc: Bool;
}

// Open Router Provider
public class OpenRouterProviderDTO {
    public let order: array<String>;
    public let allow_fallbacks: Bool;
}

public class OpenAIRequestDTO {
    public let model: String;
    public let messages: array<ref<OpenAIMessageDTO>>;

    public let provider: ref<OpenRouterProviderDTO>;
}

public class OpenAIMessageDTO {
    public let role: String;
    public let content: String;
}

// Delay callback for when a generation is not finished yet
public class HttpDelayCallback extends DelayCallback {

  public func Call() {
    let HttpRequestSystem = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"HttpRequestSystem") as HttpRequestSystem;
    HttpRequestSystem.TriggerGetRequest();
  }

  public static func Create() -> ref<HttpDelayCallback> {
    let self = new HttpDelayCallback();

    return self;
  }
}

// Delay callback for rendering messages
public class MessageDelayCallback extends DelayCallback {
  public let text: String;

  public func Call() {
    let HttpRequestSystem = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"HttpRequestSystem") as HttpRequestSystem;
    HttpRequestSystem.HandleMessage(this.text);
  }

  public static func Create(text: String) -> ref<MessageDelayCallback> {
    let self = new MessageDelayCallback();
    self.text = text;
    return self;
  }
}

// Delay callback for showing typing indicator
public class TypingDelayCallback extends DelayCallback {

  public func Call() {
    let HttpRequestSystem = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"HttpRequestSystem") as HttpRequestSystem;
    HttpRequestSystem.ToggleTypingIndicator(true);
  }

  public static func Create() -> ref<TypingDelayCallback> {
    let self = new TypingDelayCallback();

    return self;
  }
}
