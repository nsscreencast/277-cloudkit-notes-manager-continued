//
//  CloudKitFolder.swift
//  SharedNotes
//
//  Created by Ben Scheirman on 5/31/17.
//  Copyright © 2017 NSScreencast. All rights reserved.
//

import Foundation
import CloudKit

class CloudKitFolder: Folder, CKRecordWrapper {
    static let RecordType = "Folder"
    
    enum FieldKey : String {
        case name
    }
    
    let record: CKRecord
    
    var name: String {
        get { return getField(.name) ?? "" }
        set { setField(.name, value: newValue) }
    }
    
    required init(name: String) {
        self.record = CKRecord(recordType: CloudKitFolder.RecordType)
        self.name = name
    }
    
    init(folder: Folder) {
        self.record = CKRecord(recordType: CloudKitFolder.RecordType)
        self.name = folder.name
    }
    
    required init(record: CKRecord) {
        self.record = record
    }
}

extension CloudKitFolder {
    static func defaultFolder(inZone zoneID: CKRecordZoneID) -> CloudKitFolder {
        let recordID = CKRecordID(recordName: "DEFAULT_FOLDER", zoneID: zoneID)
        let record = CKRecord(recordType: CloudKitFolder.RecordType, recordID: recordID)
        let folder = CloudKitFolder(record: record)
        folder.name = "My Notes"
        return folder
    }
}
