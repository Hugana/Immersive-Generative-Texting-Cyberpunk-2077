import RedFileSystem.*
import Codeware.*
import RedData.Json.*


class PersistentStorageService extends ScriptableService {

    private const let MOD_STORAGE_NAME: String = "ImersiveTexting";
    private const let HISTORY_FILE: String = "my_config.json";
    private let m_storage: ref<FileSystemStorage>;

    private cb func OnInitialize() {
        FTLog("Game instance initialized, can access game systems");
        this.m_storage = FileSystem.GetStorage(this.MOD_STORAGE_NAME);

        if this.m_storage == null {
            FTLogError(s"InitializeStorage: FATAL ERROR: Could not retrieve unique storage '\(this.MOD_STORAGE_NAME)'. (RFS unavailable)");
        } else {
            FTLog(s"Storage initialized successfully for '\(this.MOD_STORAGE_NAME)'.");
        }
    }

    public func GetFileStorage() -> ref<FileSystemStorage> {
        return this.m_storage;
    }

    // Load the history file as a JSON object. Never returns null: a missing, empty or
    // corrupted file yields an empty object so callers can't hand null to native code.
    public func LoadHistory() -> ref<JsonObject> {
        let empty = ParseJson("{}") as JsonObject;
        if !IsDefined(this.m_storage) {
            return empty;
        }

        let file = this.m_storage.GetFile(this.HISTORY_FILE);
        if !IsDefined(file) {
            return empty;
        }

        let json = file.ReadAsJson() as JsonObject;
        if !IsDefined(json) {
            FTLogError(s"LoadHistory: '\(this.HISTORY_FILE)' is missing or not a JSON object, starting fresh.");
            return empty;
        }

        return json;
    }

    // Get the history entry for a contact, creating it if the file doesn't have it yet
    public func GetCharacterHistory(json: ref<JsonObject>, contactName: String) -> ref<JsonObject> {
        let characterObject = json.GetKey(contactName) as JsonObject;
        if !IsDefined(characterObject) {
            characterObject = ParseJson("{\"vMessages\":\"\",\"npcResponses\":\"\"}") as JsonObject;
            json.SetKey(contactName, characterObject);
        }
        return characterObject;
    }

    public func SaveHistory(json: ref<JsonObject>) {
        if !IsDefined(this.m_storage) || !IsDefined(json) {
            return;
        }

        let file = this.m_storage.GetFile(this.HISTORY_FILE);
        if !IsDefined(file) {
            return;
        }

        file.WriteJson(json);
    }

    public static func GetPersistentStorageSystem() -> ref<PersistentStorageService> {
        return GameInstance.GetScriptableServiceContainer().GetService(n"PersistentStorageService") as PersistentStorageService;
    }
}
