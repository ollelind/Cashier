//
//  Cashier.swift
//  Cashier
//
//  Created by Olof Lind on 2018-05-16.
//  Copyright © 2018 Olof Lind. All rights reserved.
//

import Foundation
import StoreKit

class Cashier: NSObject {
    
    typealias PurchaseSubscriptionResponse = ((_ success: Bool, _ error: Error?) -> Void)? // TODO: Change to a response object that includes more data such as subscription end date.
    typealias FetchSubscriptionsResponse = ((_ success: Bool, _ products: [SubscriptionProduct]?) -> Void)?
    typealias UploadReceiptResponse = ((_ success: Bool, _ processedTransactionIdentifiers: [String]?, _ error: Error?) -> Void)?
    
    static let shared = Cashier()
    
    fileprivate var productProvider = SubscriptionProductProvider()
    fileprivate var productIdentifiers: [String]?
    fileprivate var currentPurchaseSubscriptionCallback: PurchaseSubscriptionResponse
    
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    
    // MARK: Public API
    
    func setProductIdentifiers(_ identifiers: [String]) {
        self.productIdentifiers = identifiers
        productProvider.resetCachedProducts()
        
        // Pre-fetch the products so they're ready when we need them later
        productProvider.fetchProducts(forProductIdentifiers: identifiers, completion: nil)
    }
    
    /**
     *  Retrieves all previously finished transactions. Apple require that this functionality is provided in case the user switches phones or re-installs the app.
     */
    func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    /**
     *  Initiates a new purchase that will bring up the iTunes purchase prompt
     */
    func purchaseSubscription(_ subscription: SubscriptionProduct, completion: PurchaseSubscriptionResponse) {
        let payment = SKPayment(product: subscription.iTunesProduct)
        SKPaymentQueue.default().add(payment)
    }
    
    /**
     *  Retrieves the SubscriptionProducts related to the current product identifiers
     *  OBS: The product identifiers needs to be set before calling this method by calling setProductIdentifiers:
     */
    func getSubscriptionProducts(withCompletion completion: FetchSubscriptionsResponse) {
        
        guard let identifiers = productIdentifiers else {
            completion?(false, nil)
            return
        }
        
        productProvider.fetchProducts(forProductIdentifiers: identifiers) { (error, products) in
            if let products = products, error == nil {
                completion?(true, products)
            } else {
                completion?(false, nil)
            }
        }
    }
    
    // MARK: Handle payments
    
    fileprivate func handleSuccessfulTransaction(_ transaction: SKPaymentTransaction) {
        /*
            1. Retrieve the receipt
            2. Post receipt to backend
            3. In the backend response, check if transaction has been proccessed, in that case finish the transaction
            4. Call the PurchaseSubscriptionResponse callback with success
        */
    }
    
    fileprivate func handleFailedTransaction(_ transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
        currentPurchaseSubscriptionCallback?(false, transaction.error)
        
    }
    
    fileprivate func uploadReceipt(_ receipt: String, completion: UploadReceiptResponse) {

    }
    
    fileprivate func loadReceipt() -> String? {
        
        guard let receiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: receiptURL.path) else {
            print("Could not locate receipt data")
            return nil
        }
        
        guard let receiptData = try? Data(contentsOf: receiptURL) else {
            print("Could not parse receipt data")
            return nil
        }
        
        let receiptString = receiptData.base64EncodedString(options: .endLineWithCarriageReturn)
        return receiptString
    }
}

extension Cashier: SKPaymentTransactionObserver {
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        for transaction in transactions {
            switch transaction.transactionState {
            case .failed:
                handleFailedTransaction(transaction)
                break
            case .deferred:
                break
            case .purchasing:
                break
            case .purchased:
                handleSuccessfulTransaction(transaction)
                break
            case .restored:
                handleSuccessfulTransaction(transaction)
                break
            }
        }
    }
    
    
}
