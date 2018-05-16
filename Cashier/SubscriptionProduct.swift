//
//  SubscriptionProduct.swift
//  Cashier
//
//  Created by Olof Lind on 2018-05-16.
//  Copyright © 2018 Olof Lind. All rights reserved.
//

import Foundation
import StoreKit


class SubscriptionProduct: NSObject {
    
    let iTunesProduct: SKProduct
    
    var localizedTitle: String {
        return iTunesProduct.localizedTitle
    }
    
    var localizedDescription: String {
        return iTunesProduct.localizedDescription
    }
    
    var productIdentifier: String {
        return iTunesProduct.productIdentifier
    }
    
    var price: Double {
        return iTunesProduct.price.doubleValue
    }
    
    var pricePerMonth: Double {
        return price / Double(months)
    }
    
    var months: Int {
        guard let period = iTunesProduct.subscriptionPeriod else {
            return 0
        }
        
        switch period.unit {
        case .month:
            return period.numberOfUnits
        case .year:
            return period.numberOfUnits * 12
        default:
            return 0
        }
    }
    
    // Needs receipt validation
    let hasTrialPeriod: Bool = false
    
    init(product: SKProduct) {
        self.iTunesProduct = product
        super.init()
    }
    
}
