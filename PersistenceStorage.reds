import Codeware.*
import RedFileSystem.*

public class PersistenceService extends ScriptableService {
  private let m_storage: ref<FileSystemStorage>;
  private let m_storageInitialized: Bool;

  public func GetStorage() -> ref<FileSystemStorage> {
    return this.m_storage;
  }

  private cb func OnLoad() {
    if this.m_storageInitialized {
        FTLog(s"PersistenceService: Storage already initialized. Skipping GetStorage() call on save load.");
        return;
    }

    this.m_storage = FileSystem.GetStorage("JsonReaderSystem");

    if this.m_storage != null {
        this.m_storageInitialized = true;
        FTLog(s"PersistenceService: Storage initialized successfully on first run.");
    } else {
        FTLogError(s"PersistenceService: FATAL ERROR: Could not retrieve storage 'JsonReaderSystem'.");
    }
  }
}

public static func GetPersistenceService() -> ref<PersistenceService> {
  return GameInstance.GetScriptableServiceContainer().GetService(n"PersistenceService") as PersistenceService;
}