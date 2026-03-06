import Foundation
import CoreData

/// Manages offline storage of run sessions and territory captures using CoreData.
/// Uses a programmatic CoreData model (code-first, no .xcdatamodeld files).
final class OfflineStorageService {

    // MARK: - Singleton

    static let shared = OfflineStorageService()

    // MARK: - Core Data Stack

    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "RunDom", managedObjectModel: Self.createModel())
        container.loadPersistentStores { _, error in
            if let error {
                AppLogger.sync.error("CoreData load failed: \(error.localizedDescription)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()

    private var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    private init() {}

    // MARK: - Pending Run Sessions

    /// Saves a run session for later sync when online.
    func savePendingRun(_ session: RunSession) throws {
        let entity = NSEntityDescription.insertNewObject(forEntityName: "PendingRun", into: context)
        entity.setValue(session.id, forKey: "runId")
        entity.setValue(Date(), forKey: "createdAt")
        entity.setValue(0, forKey: "retryCount")

        let data = try JSONEncoder().encode(session)
        entity.setValue(data, forKey: "payload")

        try context.save()
        AppLogger.sync.info("Pending run saved: \(session.id)")
    }

    /// Returns all pending run sessions ordered by creation date.
    func getPendingRuns() throws -> [(id: String, session: RunSession, retryCount: Int)] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PendingRun")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        let results = try context.fetch(request)
        let decoder = JSONDecoder()

        return results.compactMap { object in
            guard let runId = object.value(forKey: "runId") as? String,
                  let payload = object.value(forKey: "payload") as? Data,
                  let session = try? decoder.decode(RunSession.self, from: payload),
                  let retryCount = object.value(forKey: "retryCount") as? Int else {
                return nil
            }
            return (runId, session, retryCount)
        }
    }

    /// Removes a pending run after successful sync.
    func removePendingRun(id: String) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PendingRun")
        request.predicate = NSPredicate(format: "runId == %@", id)

        let results = try context.fetch(request)
        for object in results {
            context.delete(object)
        }
        try context.save()
        AppLogger.sync.info("Pending run removed: \(id)")
    }

    /// Increments the retry count for a pending run.
    func incrementRetryCount(id: String) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PendingRun")
        request.predicate = NSPredicate(format: "runId == %@", id)

        if let object = try context.fetch(request).first {
            let current = object.value(forKey: "retryCount") as? Int ?? 0
            object.setValue(current + 1, forKey: "retryCount")
            try context.save()
        }
    }

    // MARK: - Pending Territory Captures

    /// Saves a territory capture for later sync.
    func savePendingCapture(
        h3Index: String,
        userId: String,
        userColor: String,
        distance: Double,
        seasonId: String
    ) throws {
        let entity = NSEntityDescription.insertNewObject(forEntityName: "PendingCapture", into: context)
        entity.setValue(UUID().uuidString, forKey: "captureId")
        entity.setValue(h3Index, forKey: "h3Index")
        entity.setValue(userId, forKey: "userId")
        entity.setValue(userColor, forKey: "userColor")
        entity.setValue(distance, forKey: "distance")
        entity.setValue(seasonId, forKey: "seasonId")
        entity.setValue(Date(), forKey: "createdAt")
        entity.setValue(0, forKey: "retryCount")

        try context.save()
        AppLogger.sync.info("Pending capture saved: \(h3Index)")
    }

    /// Returns all pending territory captures.
    func getPendingCaptures() throws -> [PendingCaptureData] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PendingCapture")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        let results = try context.fetch(request)
        return results.compactMap { object in
            guard let captureId = object.value(forKey: "captureId") as? String,
                  let h3Index = object.value(forKey: "h3Index") as? String,
                  let userId = object.value(forKey: "userId") as? String,
                  let userColor = object.value(forKey: "userColor") as? String,
                  let distance = object.value(forKey: "distance") as? Double,
                  let seasonId = object.value(forKey: "seasonId") as? String,
                  let retryCount = object.value(forKey: "retryCount") as? Int else {
                return nil
            }
            return PendingCaptureData(
                captureId: captureId,
                h3Index: h3Index,
                userId: userId,
                userColor: userColor,
                distance: distance,
                seasonId: seasonId,
                retryCount: retryCount
            )
        }
    }

    /// Removes a pending capture after successful sync.
    func removePendingCapture(id: String) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PendingCapture")
        request.predicate = NSPredicate(format: "captureId == %@", id)

        let results = try context.fetch(request)
        for object in results {
            context.delete(object)
        }
        try context.save()
        AppLogger.sync.info("Pending capture removed: \(id)")
    }

    /// Increments the retry count for a pending capture.
    func incrementCaptureRetryCount(id: String) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PendingCapture")
        request.predicate = NSPredicate(format: "captureId == %@", id)

        if let object = try context.fetch(request).first {
            let current = object.value(forKey: "retryCount") as? Int ?? 0
            object.setValue(current + 1, forKey: "retryCount")
            try context.save()
        }
    }

    // MARK: - Counts

    /// Returns the number of pending items waiting for sync.
    var pendingCount: Int {
        let runCount = (try? context.count(for: NSFetchRequest<NSManagedObject>(entityName: "PendingRun"))) ?? 0
        let captureCount = (try? context.count(for: NSFetchRequest<NSManagedObject>(entityName: "PendingCapture"))) ?? 0
        return runCount + captureCount
    }

    /// Returns true if there are any pending items.
    var hasPendingItems: Bool {
        pendingCount > 0
    }

    // MARK: - Cleanup

    /// Removes all pending items (e.g., after user signs out).
    func clearAll() throws {
        let runRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PendingRun")
        let captureRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PendingCapture")

        let runDelete = NSBatchDeleteRequest(fetchRequest: runRequest)
        let captureDelete = NSBatchDeleteRequest(fetchRequest: captureRequest)

        try context.execute(runDelete)
        try context.execute(captureDelete)
        try context.save()
        AppLogger.sync.info("All pending items cleared")
    }

    // MARK: - CoreData Model (Programmatic)

    private static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // PendingRun entity
        let pendingRun = NSEntityDescription()
        pendingRun.name = "PendingRun"
        pendingRun.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        pendingRun.properties = [
            attribute("runId", .stringAttributeType),
            attribute("payload", .binaryDataAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("retryCount", .integer32AttributeType, defaultValue: 0)
        ]

        // PendingCapture entity
        let pendingCapture = NSEntityDescription()
        pendingCapture.name = "PendingCapture"
        pendingCapture.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        pendingCapture.properties = [
            attribute("captureId", .stringAttributeType),
            attribute("h3Index", .stringAttributeType),
            attribute("userId", .stringAttributeType),
            attribute("userColor", .stringAttributeType),
            attribute("distance", .doubleAttributeType, defaultValue: 0.0),
            attribute("seasonId", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("retryCount", .integer32AttributeType, defaultValue: 0)
        ]

        model.entities = [pendingRun, pendingCapture]
        return model
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.defaultValue = defaultValue
        attr.isOptional = defaultValue != nil
        return attr
    }
}

// MARK: - Pending Capture Data

struct PendingCaptureData {
    let captureId: String
    let h3Index: String
    let userId: String
    let userColor: String
    let distance: Double
    let seasonId: String
    let retryCount: Int
}
