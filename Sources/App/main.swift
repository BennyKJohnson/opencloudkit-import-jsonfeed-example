import Vapor
import OpenCloudKit
import Foundation

let drop = Droplet()


let config = try CKConfig(contentsOfFile: "\(drop.workDir)cloudkit.json")
CloudKit.shared.configure(with: config)

var existingFireIncidents: Set<FireIncident>!

// Query for existing fire incidents
func queryFireIncidentsFromCloud(completion: @escaping ([CKRecord]?, Error?) -> Void) {
    
    // Prepare Query
    let query = CKQuery(recordType: FireIncidentRecordType, filters: [])
    
    let container = CKContainer.default()
    let database = container.publicCloudDatabase
    
    // Perform query
    database.perform(query: query, inZoneWithID: nil, completionHandler: completion)
}



func parseIncidents(fromJSON JSON: [String: Any]) -> [FireIncident] {
    guard let featuresArray = JSON["features"] as? [[String: Any]] else {
        return []
    }
    
    print("Found \(featuresArray.count) Fire Incidents")
    let incidents:[FireIncident] = featuresArray.flatMap { (featureJSON) -> FireIncident? in
        return FireIncident(json: featureJSON)
    }
    print("Parsed \(featuresArray.count) Fire Incidents")
    
    return incidents
}

func getExistingFireIncidents(completion: @escaping (Set<FireIncident>?, Error?) -> Void) {
    
    if let existingFireIncidents = existingFireIncidents {
        completion(existingFireIncidents, nil)
    } else {
        queryFireIncidentsFromCloud { (records, error) in
            if let records = records {
                
                let incidents = records.flatMap({ (cloudRecord) -> FireIncident? in
                    return FireIncident(record: cloudRecord)
                })
                
                existingFireIncidents = Set<FireIncident>(minimumCapacity: incidents.count)
                for incident in incidents {
                    existingFireIncidents?.insert(incident)
                }
                completion(existingFireIncidents, error)
            }
        }
    }
}

func performFireIncidentsFetch(completion: @escaping ([FireIncident]?, Error?) -> Void) {
    let fireIncidentsURL = URL(string: "http://www.rfs.nsw.gov.au/feeds/majorIncidents.json")!
    
    let request = URLSession.shared.dataTask(with: fireIncidentsURL) { (data, response, error) in
        if let error = error {
            print(error)
            completion(nil, error)
        } else if let data = data {
            let jsonData = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            let incidents = parseIncidents(fromJSON: jsonData)
            completion(incidents, nil)
            
        }
    }
    
    request.resume()
}

func modifyIncidents(incidentsToSave: [FireIncident], incidentsToDelete: [FireIncident]) {
    
    let recordsToSave: [CKRecord] = incidentsToSave.map { (incident) -> CKRecord in
        return incident.serializeRecord()
    }
    
    let recordIDsToDelete: [CKRecordID] = []
    
    let modifyOperation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
    
    modifyOperation.modifyRecordsCompletionBlock = {
        (records, deleted, error) in
        
        if let error = error {
            print(error)
        } else {
            if let records = records {
                // Convert records to incidents
                let incidents = records.flatMap({ (cloudRecord) -> FireIncident? in
                    return FireIncident(record: cloudRecord)
                })
                
                // Append to existing incidents
                for incident in incidents {
                    existingFireIncidents.insert(incident)
                }
            }
            
            if deleted?.count == incidentsToDelete.count {
                // Remove deleted objects from existing
                for deletedIncident in incidentsToDelete {
                    existingFireIncidents.remove(deletedIncident)
                }
            }
        }
    }
    
    print("Saving \(recordsToSave.count), Deleting \(recordIDsToDelete.count) Incidents from iCloud")
    
    CKContainer.default().publicCloudDatabase.add(modifyOperation)
}

func updateFireIncidents() {
    // Get existing fire incidents from Cache or if cache is empty fetch from iCloud
    getExistingFireIncidents { (existingIncidents, error) in
        if let error = error {
            print(error)
        } else if let existingIncidents = existingIncidents {
            // Fetch Fire Incidents from data source
            performFireIncidentsFetch { (incidents, error) in
                if let error = error {
                    print(error)
                } else if let incidents = incidents {
                    let incidentSet = Set<FireIncident>(incidents)
                    
                    // Get records that have been removed from feed based on existing
                    let deletedIncidents = existingIncidents.subtracting(incidents).array
                    // Get records that have been added to the feed
                    let addedIncidents = incidentSet.subtracting(existingIncidents).array
                    
                    modifyIncidents(incidentsToSave: addedIncidents, incidentsToDelete: deletedIncidents)
                    
                }
            }
        }
    }
}


drop.get { req in
    return try drop.view.make("welcome", [
    	"message": drop.localization[req.lang, "welcome", "title"]
    ])
}

updateFireIncidents()

drop.run()
