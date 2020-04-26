//
//  NewCarbEntry.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public struct NewCarbEntry: CarbEntry, Equatable, RawRepresentable {
    public typealias RawValue = [String: Any]

    public let quantity: HKQuantity
    public let quantityFat: HKQuantity?
    public let quantityProtein: HKQuantity?
    public let startDate: Date
    public let foodType: String?
    public var absorptionTime: TimeInterval?
    public let createdByCurrentApp = true
    public let externalID: String?
    public let syncIdentifier: String?
    public let isUploaded: Bool

    public init(quantity: HKQuantity, startDate: Date, foodType: String?, absorptionTime: TimeInterval?, isUploaded: Bool = false, externalID: String? = nil, syncIdentifier: String? = nil, quantityFat: HKQuantity? = nil, quantityProtein: HKQuantity? = nil) {
        self.quantityFat = quantityFat
        self.quantityProtein = quantityProtein
        self.startDate = startDate
        self.foodType = foodType
        self.absorptionTime = absorptionTime
        self.isUploaded = isUploaded
        self.externalID = externalID
        self.syncIdentifier = syncIdentifier

        if quantityFat != nil && quantityProtein != nil {
            let caloriesFat = quantityFat!.doubleValue(for: .gram()) * 9
            let caloriesProtein = quantityProtein!.doubleValue(for: .gram()) * 4

            let fatProteinUnits = (caloriesFat + caloriesProtein) / 100
            let carbEquivalentQuantity = fatProteinUnits * 10
            let duration: Double
            switch fatProteinUnits {
            case 0..<1.0:
                duration = 2.0
            case 1.0..<2.0:
                duration = 3.0
            case 2.0..<3.0:
                duration = 4.0

            case 3.0..<4.0:
                duration = 5.0
            default:
                duration = 8.0
            }

            self.absorptionTime = TimeInterval(hours: duration)
            self.quantity = HKQuantity(unit: .gram(), doubleValue: carbEquivalentQuantity)
        } else {
            self.quantity = quantity
        }

    }

    public init?(rawValue: RawValue) {
        guard
            let grams = rawValue["grams"] as? Double,
            let startDate = rawValue["startDate"] as? Date
        else {
            return nil
        }

        let externalID = rawValue["externalID"] as? String

        self.init(
            quantity: HKQuantity(unit: .gram(), doubleValue: grams),
            startDate: startDate,
            foodType: rawValue["foodType"] as? String,
            absorptionTime: rawValue["absorptionTime"] as? TimeInterval,
            isUploaded: externalID != nil,
            externalID: externalID,
            syncIdentifier: rawValue["syncIdentifier"] as? String
        )
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "grams": quantity.doubleValue(for: .gram()),
            "startDate": startDate
        ]

        rawValue["foodType"] = foodType
        rawValue["absorptionTime"] = absorptionTime
        rawValue["externalID"] = externalID
        rawValue["syncIdentifier"] = syncIdentifier

        return rawValue
    }
}


extension NewCarbEntry {
    func createSample(from oldEntry: StoredCarbEntry? = nil, syncVersion: Int = 1) -> HKQuantitySample {
        var metadata = [String: Any]()

        if let absorptionTime = absorptionTime {
            metadata[MetadataKeyAbsorptionTimeMinutes] = absorptionTime
        }

        if let foodType = foodType {
            metadata[HKMetadataKeyFoodType] = foodType
        }

        if let oldEntry = oldEntry, let syncIdentifier = oldEntry.syncIdentifier {
            metadata[HKMetadataKeySyncVersion] = oldEntry.syncVersion + 1
            metadata[HKMetadataKeySyncIdentifier] = syncIdentifier
        } else {
            // Add a sync identifier to allow for atomic modification if needed
            metadata[HKMetadataKeySyncVersion] = syncVersion
            metadata[HKMetadataKeySyncIdentifier] = syncIdentifier ?? UUID().uuidString
        }

        metadata[HKMetadataKeyExternalUUID] = externalID

        return HKQuantitySample(
            type: HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            quantity: quantity,
            start: startDate,
            end: endDate,
            metadata: metadata
        )
    }
}
