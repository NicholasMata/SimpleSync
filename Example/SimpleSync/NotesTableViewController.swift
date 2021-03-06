//
//  PersonTableViewController.swift
//  SimpleSync
//
//  Created by Nicholas Mata on 2/1/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import CoreData
import SimpleSync

class NoteCell: UITableViewCell {
    @IBOutlet weak var bodyLabel: UILabel!
}

class NotesTableViewController: UITableViewController {
    
    var startedSyncOn: Date?
    var endedSyncOn: Date?
    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>!
    
    var sync: SimpleSync!
    
    func initializeFetchedResultsController() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Note")
        let initialSort = NSSortDescriptor(key: "id", ascending: true)
        request.sortDescriptors = [initialSort]
        
        let moc = CoreDataManager.shared.managedObjectContext
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: nil, cacheName: nil)
        // For smaller data sets this is better.
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("Failed to initialize FetchedResultsController: \(error)")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        initializeFetchedResultsController()
        let dataManager = CoreDataManager.shared
        
        let syncInfo = EntitySyncInfo(dataManager: dataManager,  entityName: "Note")
        let url = "http://192.168.2.2/api/notes"
        sync = SimpleSync(startUrl: url, info: syncInfo)
        // If endpoint is secure add Authorization Header
//        sync.headers = ["Authorization": "Bearer INSERTTOKENHERE]
        sync.delegate = self
        sync.start()
        startedSyncOn = Date()
        
        self.refreshControl?.addTarget(self, action: #selector(self.startSync), for: .valueChanged)
    }
    
    @objc func startSync() {
        sync.start()
        startedSyncOn = Date()
    }
}

extension NotesTableViewController: SimpleSyncDelegate {
    func simpleSync(_ sync: SimpleSync, fill entity: NSManagedObject, with json: [String : Any]) {
        self.fill(note: entity, with: json)
    }
    
    func simpleSync(_ sync: SimpleSync, new entity: NSManagedObject, with json: [String : Any]) {
        self.fill(note: entity, with: json)
    }
    
    private func fill(note: NSManagedObject, with json: [String:Any]) {
        guard let note = note as? Note else {
            return
        }
        let id = json["id"] as! Int64
        SimpleSync.updateIfChanged(note, key: "id", value: id)
        let body = json["body"] as? String
        SimpleSync.updateIfChanged(note, key: "body", value: body)
    }
    
    func simpleSync(_ sync: SimpleSync, needsRemoval entity: NSManagedObject) {
        guard let note = entity as? Note else {
            return
        }
        let noteId = note.id
        print("\(noteId) needs removal")

        CoreDataManager.shared.managedObjectContext.delete(note)
        do {
            try CoreDataManager.shared.managedObjectContext.save()
        } catch let error {
            print(error)
        }
       

        print("\(noteId) was removed")
    }
    
    func simpleSync(finished sync: SimpleSync) {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("Failed to initialize FetchedResultsController: \(error)")
        }
        endedSyncOn = Date()
        print("Sync took: \(endedSyncOn!.timeIntervalSince(startedSyncOn!)) secs")
        DispatchQueue.main.async {
            self.refreshControl?.endRefreshing()
        }
    }
    
}

extension NotesTableViewController {
    
    func configureCell(_ cell: UITableViewCell, indexPath: IndexPath) {
        guard let selectedObject = fetchedResultsController.object(at: indexPath) as? Note else { fatalError("Unexpected Object in FetchedResultsController")
        }
        guard let cell = cell as? NoteCell else {
            fatalError("Invalid cell class")
        }
        cell.bodyLabel.text = selectedObject.body
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return fetchedResultsController.sections?[section].indexTitle
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return fetchedResultsController.sectionIndexTitles
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath)
        // Set up the cell
        configureCell(cell, indexPath: indexPath)
        return cell
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = fetchedResultsController.sections else {
            fatalError("No sections in fetchedResultsController")
        }
        let sectionInfo = sections[section]
        return sectionInfo.numberOfObjects
    }
}

// Set delegate in viewDidLoad to use these methods.
// Only recommended for smaller data sets.
extension NotesTableViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            configureCell(tableView.cellForRow(at: indexPath!)!, indexPath: indexPath!)
        case .move:
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(NSIndexSet(index: sectionIndex) as IndexSet, with: .fade)
        case .delete:
            tableView.deleteSections(NSIndexSet(index: sectionIndex) as IndexSet, with: .fade)
        case .move:
            break
        case .update:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
