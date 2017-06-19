//
//  ViewController.swift
//  SharedNotes
//
//  Created by Ben Scheirman on 5/15/17.
//  Copyright © 2017 NSScreencast. All rights reserved.
//

import UIKit

protocol FoldersCoordinationDelegate : class {
    func addTapped(from: FoldersViewController)
    func didSelect(folder: Folder, from: FoldersViewController)
    func didCommitDelete(folder: Folder, atIndexPath: IndexPath, from: FoldersViewController)
}

final class FoldersViewController: UITableViewController, StoryboardInitializable {

    weak var coordinationDelegate: FoldersCoordinationDelegate?
    var foldersDatasource: FoldersDatasource!
    var notesManager: NotesManager!
    
    let FolderCell = "FolderCell"
    let FolderSegue = "folderSegue"
    
    var folders: [Folder] = []

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchFolders()
    }
    
    private func fetchFolders() {
        foldersDatasource.fetchFolders { result in
            switch result {
            case .success(let folders):
                self.folders = folders
                self.tableView.reloadData()
                
            case .error(let e):
                print(e)
                self.displayError(message: "Could not load folders.")
            }
        }
    }

    @IBAction func addTapped(_ sender: Any) {
        coordinationDelegate?.addTapped(from: self)
    }
    
    // MARK: - Table View
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return folders.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FolderCell, for: indexPath)
        let folder = folders[indexPath.row]
        cell.textLabel?.text = folder.name
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        let folder = folders[indexPath.row]
        switch editingStyle {
        case .delete:
            coordinationDelegate?.didCommitDelete(folder: folder, atIndexPath: indexPath, from: self)
        default: break
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let folder = folders[indexPath.row]
        coordinationDelegate?.didSelect(folder: folder, from: self)
    }
}

    
