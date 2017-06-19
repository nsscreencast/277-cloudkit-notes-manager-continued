//
//  AppCoordinator.swift
//  SharedNotes
//
//  Created by Ben Scheirman on 5/23/17.
//  Copyright © 2017 NSScreencast. All rights reserved.
//

import Foundation
import UIKit

class AppCoordinator {
    
    private let FirstLaunchKey = "firstLaunch"
    
    let window: UIWindow
    var root: UINavigationController!
    
    let notesManager: NotesManager
    let userDefaults: UserDefaults = .standard
    
    var isFirstLaunch: Bool {
        get { return true } // return userDefaults.bool(forKey: FirstLaunchKey) }
        set { userDefaults.set(newValue, forKey: FirstLaunchKey) }
    }
    
    init(window: UIWindow, defaults: UserDefaults = .standard) {
        self.window = window
        notesManager = CloudKitNotesManager.sharedInstance
    }
    
    func handleFirstLaunch() {
        print("... first launch, do we need to create default folder?")
        let group = DispatchGroup()
        group.enter()
        
        notesManager.createDefaultFolder { result in
            if case let .error(e) = result {
                print(e)
                DispatchQueue.main.async {
                    self.window.rootViewController?.displayError(message: "Could not create default folder. Check connection?")
                }
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isFirstLaunch = false
            print("Setting root VC")
            
            self.transitionRoot(to: self.root)
        }
    }
    
    func transitionRoot(to vc: UIViewController) {
        let overlayView = UIScreen.main.snapshotView(afterScreenUpdates: false)
        vc.view.addSubview(overlayView)
        window.rootViewController = vc
        
        UIView.animate(withDuration: 0.4, delay: 0, options: .transitionCrossDissolve, animations: {
            overlayView.alpha = 0
        }, completion: { finished in
            overlayView.removeFromSuperview()
        })
    }
    
    func start() {
        let foldersVC = FoldersViewController.makeFromStoryboard()
        foldersVC.notesManager = notesManager
        foldersVC.foldersDatasource = FoldersDatasource(noteManager: notesManager)
        foldersVC.coordinationDelegate = self
        root = foldersVC.wrapWithNavigationController()
        
        print("checking first launch...")
        if isFirstLaunch {
            let waitingVC = InitialSetupViewController()
            window.rootViewController = waitingVC
            handleFirstLaunch()
        } else {
            window.rootViewController = root
        }
        
        window.makeKeyAndVisible()
    }
}

extension AppCoordinator : FoldersCoordinationDelegate {
    func didSelect(folder: Folder, from: FoldersViewController) {
        print("didSelect(folder: \(folder.name))")
        
        let noteListVC = NotesListViewController.makeFromStoryboard()
        noteListVC.coordinationDelegate = self
        noteListVC.notesDatasource = NotesDatasource(parent: folder, noteManager: notesManager)
        noteListVC.folder = folder
        
        root.pushViewController(noteListVC, animated: true)
    }
    
    func addTapped(from vc: FoldersViewController) {
        vc.promptForValue(title: "New Folder", message: nil, placeholder: "Name", buttonTitle: "Add") { (name) in
            let folder = self.notesManager.newFolder(name: name ?? "<unnamed>")
            self.notesManager.save(folder: folder) { (result) in
                switch result {
                case .success(let folder):
                    DispatchQueue.main.async {
                        vc.folders.insert(folder, at: 0)
                        vc.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
                    }
                case .error(let e):
                    print(e)
                    DispatchQueue.main.async {
                        vc.displayError(message: "Folder could not be added.")
                    }
                }
            }
        }
    }
    
    func didCommitDelete(folder: Folder, atIndexPath indexPath: IndexPath, from vc: FoldersViewController) {
        notesManager.delete(folder: folder) { result in
            switch result {
            case .success(_):
                DispatchQueue.main.async {
                    vc.folders.remove(at: indexPath.row)
                    vc.tableView.deleteRows(at: [indexPath], with: .automatic)
                }
            case .error(let e):
                print(e)
                DispatchQueue.main.async {
                    vc.displayError(message: "Error deleting folder.")
                }
            }
        }
    }
}

extension AppCoordinator : NoteListCoordinationDelegate {
    func didSelect(note: Note, from: NotesListViewController) {
        let noteVC = NoteViewController.makeFromStoryboard()
        noteVC.notesManager = notesManager
        noteVC.note = note
        
        root.pushViewController(noteVC, animated: true)
    }
    
    func newNoteTapped(from noteListVC: NotesListViewController) {
        let folder = noteListVC.folder!
        let note = notesManager.newNote(in: folder)
        
        self.notesManager.save(note: note) { result in
            switch result {
            case .success(let note):
                DispatchQueue.main.async {
                    let indexPath = noteListVC.notesDatasource.insert(note: note, at: 0)
                    noteListVC.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
                    
                    self.didSelect(note: note, from: noteListVC)
                }
            case .error(let e):
                print(e)
                DispatchQueue.main.async {
                    noteListVC.displayError(message: "Error saving note")
                }
            }
        }
        
        
        
    }
}
