import RedFileSystem.*
import Codeware.*
import RedData.Json.*


class PersistentStorageService extends ScriptableService {

    private const let MOD_STORAGE_NAME: String = "ImersiveTexting";  
    private persistent let m_storage: ref<FileSystemStorage>; 

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

    public static func GetPersistentStorageSystem() -> ref<PersistentStorageService> {
        return GameInstance.GetScriptableServiceContainer().GetService(n"PersistentStorageService") as PersistentStorageService;
    }
}