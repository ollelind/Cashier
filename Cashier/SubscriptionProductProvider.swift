//
//  SubscriptionProductProvider.swift
//  Cashier
//
//  Created by Olof Lind on 2018-05-16.
//  Copyright © 2018 Olof Lind. All rights reserved.
//

import Foundation
import StoreKit

/*
 *  Wrapper around SKProductRequest to fetch SKProducts from iTunes and map into SubscriptionProduct objects
 */
class SubscriptionProductProvider: NSObject {
    
    typealias SubscriptionProductsResponse = ((Error?, [SubscriptionProduct]?) -> Void)?
    
    fileprivate var productsFetchCompletion: SubscriptionProductsResponse
    fileprivate static var cachedSubscriptionProducts: [SubscriptionProduct]?
    
    override init() {
        super.init()
    }
    
    func fetchProducts(forProductIdentifiers identifiers: [String], completion: SubscriptionProductsResponse) {
        
        // First check if we've already fetched & cached the products, then there's no need to retrieve them again from iTunes
        if let cachedSubscriptions = SubscriptionProductProvider.cachedSubscriptionProducts {
            completion?(nil, cachedSubscriptions)
            return
        }
        
        // Save a reference to the completion closure as we need to invoke it after the iTunes product request callback
        productsFetchCompletion = completion
        
        let request = SKProductsRequest(productIdentifiers: Set(identifiers))
        request.delegate = self
        request.start()
    }
    
    func resetCachedProducts() {
        SubscriptionProductProvider.cachedSubscriptionProducts = nil
    }
    
    fileprivate func handleProductResponse(_ response: [SKProduct]) {
        
        let subscriptionProducts = response.map { (iTunesProduct) -> SubscriptionProduct in
            return SubscriptionProduct(product: iTunesProduct)
        }
        
        SubscriptionProductProvider.cachedSubscriptionProducts = subscriptionProducts
        
        productsFetchCompletion?(nil, subscriptionProducts)
    }
}

extension SubscriptionProductProvider: SKProductsRequestDelegate {
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        handleProductResponse(response.products)
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        productsFetchCompletion?(error, nil)
    }
}


