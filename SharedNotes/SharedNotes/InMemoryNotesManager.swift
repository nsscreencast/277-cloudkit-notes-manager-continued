//
//  InMemoryNotesManager.swift
//  SharedNotes
//
//  Created by Ben Scheirman on 5/31/17.
//  Copyright © 2017 NSScreencast. All rights reserved.
//

import Foundation

class InMemoryNotesManager : NotesManager {
    static var sharedInstance: NotesManager = InMemoryNotesManager()
    
    private var folders: [String : Folder] = [:]
    private var notes: [String : Note] = [:]
    
    private init() {
    }
    
    static var hasCreatedDefaultFolder: Bool {
        return false
    }
    
    // MARK: - Folders
    
    public func createDefaultFolder(completion: @escaping (Result<Folder>) -> Void) {
        return completion(.success(InMemoryFolder(name: "My Notes")))
    }
    
    public func fetchFolders(completion: @escaping OperationCompletionBlock<[Folder]>) {
        let sortedFolders = folders.values.sorted { (a, b) in
            guard let createdA = a.createdAt, let createdB = b.createdAt else {
                fatalError("Saved folders must have non-nil createdAt dates.")
            }
            
            return createdA < createdB
        }
        completion(.success(sortedFolders))
    }
    
    public func save(folder: Folder, completion: @escaping OperationCompletionBlock<Folder>) {
        guard let folder = folder as? InMemoryFolder else { return }
        
        if folder.identifier == nil {
            folder.identifier = UUID().uuidString
            folder.createdAt = Date()
        }
        
        folders[folder.identifier!] = folder
        
        completion(.success(folder))
    }
    
    public func delete(folder: Folder, completion: @escaping OperationCompletionBlock<Bool>) {
        if let id = folder.identifier {
            folders.removeValue(forKey: id)
        }
        
        completion(.success(true))
    }
    
    public func newFolder(name: String) -> Folder {
        return InMemoryFolder(name: name)
    }
    
    // MARK: - Notes
    
    public func newNote(in folder: Folder) -> Note {
        let note = InMemoryNote()
        note.folderIdentifier = folder.identifier
        return note
    }
    
    public func fetchNotes(for: Folder, completion: @escaping OperationCompletionBlock<[Note]>) {
        let sortedNotes = notes.values.sorted { (a, b) in
            guard let modifiedA = a.modifiedAt, let modifiedB = b.modifiedAt else {
                fatalError("Saved notes must have a non-nil modified date.")
            }
            
            return modifiedA < modifiedB
        }
        completion(.success(sortedNotes))
    }
    
    public func save(note: Note, completion: @escaping OperationCompletionBlock<Note>) {
        
        let savedNote = InMemoryNote(note: note)
        savedNote.identifier ??= UUID().uuidString
        savedNote.createdAt ??= Date()
        savedNote.content = note.content
        savedNote.modifiedAt = Date()
        
        notes[savedNote.identifier!] = savedNote
        
        completion(.success(savedNote))
    }
}
