//
//  FireIncident.swift
//  cloudkit
//
//  Created by Ben Johnson on 5/11/16.
//
//

import Foundation
import OpenCloudKit

protocol RecordSerialable {
    
    func serializeRecord() -> CKRecord
    
}

let FireIncidentRecordType = "FireIncident"

struct FireIncident {
  
    let title: String
    
    let urlPath: String
    
    let guid: String
    
    let incidentDescription: String
    
    let location: CKLocation
    
     init?(json: [String: Any]) {
        guard
            let properties = json["properties"] as? [String: Any],
            let geometry = json["geometry"] as? [String:Any] else {
            return nil
        }
        
        // Get all required properties
        guard
            let titleValue = properties["title"] as? String,
            let guidValue = properties["guid"] as? String,
            let descriptionValue = properties["description"] as? String,
            let urlValue = properties["link"] as? String else {
                return nil
        }
        
        // Get all coordinate values 
        guard
            let geometries = geometry["geometries"] as? [[String:AnyObject]],
            let coordinates = geometries[0]["coordinates"] as? [NSNumber],
            let longitude = coordinates.first?.doubleValue,
            let latitude = coordinates.last?.doubleValue else {
            return nil
        }
            
        
        // Set all properties
        title = titleValue
        guid = guidValue
        incidentDescription = descriptionValue
        urlPath = urlValue
    
        // Set location
        location = CKLocation(latitude: latitude, longitude: longitude)
   
     }
 
    
    init(record: CKRecord) {
        
        title = record["title"] as! String
        urlPath = record["url"] as! String
        guid = record["guid"] as! String
        incidentDescription = record["description"] as! String
        location = record["location"] as! CKLocation
        
    }
    
    func serializeRecord() -> CKRecord {
       
        let record = CKRecord(recordType: "FireIncident", recordID: CKRecordID(recordName: guid, zoneID: CKRecordZone.default().zoneID))
        record["title"] = title
        record["location"] = location
        record["url"] = urlPath
        record["description"] = incidentDescription
        record["guid"] = guid
        
        return record
    }
}

extension FireIncident: Hashable {
    public static func ==(lhs: FireIncident, rhs: FireIncident) -> Bool {
        return lhs.guid == rhs.guid
    }

    public var hashValue: Int {
        return guid.hashValue
    }
}

