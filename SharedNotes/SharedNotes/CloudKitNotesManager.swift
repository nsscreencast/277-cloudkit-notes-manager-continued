//
//  CloudKitNotesManager.swift
//  SharedNotes
//
//  Created by Ben Scheirman on 5/23/17.
//  Copyright © 2017 NSScreencast. All rights reserved.
//

import Foundation
import CloudKit

class CloudKitNotesManager : NotesManager {
    static var sharedInstance: NotesManager = CloudKitNotesManager(database: CKContainer.default().privateCloudDatabase)
    
    private let database: CKDatabase
    private let zoneID: CKRecordZoneID
    
    init(database: CKDatabase) {
        self.database = database
        self.zoneID = CKRecordZone.default().zoneID
    }
    
    private static let hasCreatedDefaultFolderKey = "hasCreatedDefaultFolder"
    static var hasCreatedDefaultFolder: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hasCreatedDefaultFolderKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hasCreatedDefaultFolderKey)
        }
    }
    
    func createDefaultFolder(completion: @escaping OperationCompletionBlock<Folder>) {
        let folder = CloudKitFolder.defaultFolder(inZone: zoneID)
        
        database.save(folder.record) { (record, error) in
            if let e = error as? CKError {
                if e.code == CKError.Code.serverRecordChanged {
                    // silently fail, it already exists...
                    let serverFolder = CloudKitFolder(record: e.serverRecord!)
                    completion(.success(serverFolder))
                } else {
                    completion(.error(e))
                }
            } else if let e = error {
                completion(.error(e))
            } else if let record = record {
                CloudKitNotesManager.hasCreatedDefaultFolder = true
                let folder = CloudKitFolder(record: record)
                completion(.success(folder))
            }
        }
    }
    
    func fetchFolders(completion: @escaping (Result<[Folder]>) -> Void) {
        let all = NSPredicate(value: true)
        let sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        query(predicate: all,
              sortDescriptors: sortDescriptors,
              conversion: { (folder: CloudKitFolder) -> Folder in folder },
              completion: completion)
    }
    
    func newFolder(name: String) -> Folder {
        return CloudKitFolder(name: name)
    }
    
    func save(folder: Folder, completion: @escaping (Result<Folder>) -> Void) {
        guard let folder = folder as? CloudKitFolder else { fatalError("must pass in a CloudKitFolder") }
        save(record: folder, conversion: { $0 }, completion: completion)
    }
    
    func delete(folder: Folder, completion: @escaping (Result<Bool>) -> Void) {
        guard let folder = folder as? CloudKitFolder else { fatalError("must pass in a CloudKitFolder") }
        delete(record: folder, completion: completion)
    }
    
    func newNote(in folder: Folder) -> Note {
        let note = CloudKitNote(zoneID: zoneID)
        note.folderIdentifier = folder.identifier
        return note
    }
    
    func fetchNotes(for folder: Folder, completion: @escaping (Result<[Note]>) -> Void) {
        guard let folder = folder as? CloudKitFolder else { fatalError("must pass in a CloudKitFolder") }
        
        let inFolderPredicate = NSPredicate(format: "folder == %@", CKReference(recordID: folder.record.recordID, action: .deleteSelf))
        let sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        query(predicate: inFolderPredicate,
              sortDescriptors: sortDescriptors,
              conversion: { (note: CloudKitNote) -> Note in note },
              completion: completion)
    }
    
    func save(note: Note, completion: @escaping (Result<Note>) -> Void) {
        guard let note = note as? CloudKitNote else { fatalError("must pass in a CloudKitNote") }
        save(record: note, conversion: { $0 }) { result in
            
            switch result {
            case .success(let savedNote):
                NotificationCenter.default.post(name: .NoteWasUpdated, object: savedNote)
                completion(.success(savedNote))
            case .error(let e):
                completion(.error(e))
            }
        }
    }
    
    private func save<R, T>(record: R, conversion: @escaping (R) -> T, completion: @escaping OperationCompletionBlock<T>) where R : CKRecordWrapper  {
        let modifyOp = CKModifyRecordsOperation(recordsToSave: [record.record], recordIDsToDelete: nil)
        modifyOp.modifyRecordsCompletionBlock = { savedRecords, deletedRecords, error in
            if let e = error {
                print("Error saving record: \(e)")
                completion(.error(e))
            }
            if let savedRecord = savedRecords?.first {
                let result = R(record: savedRecord)
                completion(.success(conversion(result)))
            }
        }
        database.add(modifyOp)
    }
    
    private func delete<R:CKRecordWrapper>(record: R, completion: @escaping OperationCompletionBlock<Bool>) {
        let modifyOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [record.record.recordID])
        modifyOp.modifyRecordsCompletionBlock = { saved, deletedIds, error in
            if let e = error {
                print("Error deleting record: \(e)")
                completion(.error(e))
            } else {
                let deletedCount = deletedIds?.count ?? 0
                completion(.success(deletedCount > 0))
            }
        }
        database.add(modifyOp)
    }
 
    private func query<R, T>(predicate: NSPredicate, sortDescriptors: [NSSortDescriptor], conversion: @escaping (R) -> T, completion: @escaping OperationCompletionBlock<[T]>) where R : CKRecordWrapper {
        let query = CKQuery(recordType: R.RecordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors
        
        let queryOperation = CKQueryOperation(query: query)
        var results: [R] = []
        queryOperation.recordFetchedBlock = { record in
            results.append(R(record: record))
        }
        queryOperation.queryCompletionBlock = { cursor, error in
            // ignore cursor for now
            
            if let e = error as? CKError, e.code == CKError.Code.unknownItem {
                // we'll let the first save define it, for now just return an empty collection
                completion(.success([]))
            } else if let e = error {
                completion(.error(e))
            } else {
                completion(.success(results.map(conversion)))
            }
        }
        
        database.add(queryOperation)
    }
}
