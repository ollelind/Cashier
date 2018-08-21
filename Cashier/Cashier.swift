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
    
    typealias PurchaseSubscriptionResponse = ((_ success: Bool, _ expiresDate: Date?, _ error: Error?) -> Void)? // TODO: Change to a response object that includes more data such as subscription end date.
    
    static let shared = Cashier()
    
    fileprivate var productProvider = SubscriptionProductProvider()
    fileprivate var productIdentifiers: [String]?
    fileprivate var currentPurchaseSubscriptionCallback: PurchaseSubscriptionResponse
    
    var reciptPublishURL: URL? = URL(string: "https://us-central1-greenfingers-f5408.cloudfunctions.net/checkReceipt")
    
    
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    
    // MARK: Public API
    // Caches product identifiers for future use
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
        currentPurchaseSubscriptionCallback = completion
        let payment = SKPayment(product: subscription.iTunesProduct)
        SKPaymentQueue.default().add(payment)
    }
    
    /**
     *  Retrieves the SubscriptionProducts related to the current product identifiers
     *  OBS: The product identifiers needs to be set before calling this method by calling setProductIdentifiers:
     */
    func getSubscriptionProducts(withCompletion completion: ((_ success: Bool, _ products: [SubscriptionProduct]?) -> Void)?) {
        
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
        
        guard let receipt = loadReceipt() else {
            return
        }
        
        uploadReceipt(receipt) { (expiresDate, transactions, error) in
            if let proccessedTransaction = transactions?.filter({ $0 == transaction.transactionIdentifier }).first {
                SKPaymentQueue.default().finishTransaction(transaction)
                currentPurchaseSubscriptionCallback?(true, expiresDate, error)
            }
        }
        
    }
    
    fileprivate func handleFailedTransaction(_ transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
        currentPurchaseSubscriptionCallback?(false, nil, transaction.error)
    }
    
    fileprivate func uploadReceipt(_ receipt: String, completion: ((_ expiresDate: Date?, _ processedTransactions: [String]?, _ error: Error?) -> Void)?) {
        
        guard let url = reciptPublishURL else {
            return
        }
        
        let parameters: [String : Any] = [
            "is_sandbox" : true,
            "receipt" : receipt
        ]
        
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = [
            "Content-Type" : "application/json"
        ]
        request.httpBody = try! JSONSerialization.data(withJSONObject: parameters, options: .init(rawValue: 0))
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
            
            if let error = error {
                DispatchQueue.main.async {
                    print("error!")
                }
                return
            }
            
            if let response = response {
                print(response)
            }
            
            do {
                guard let data = data else {
                    return
                }
                
                // Handle data
                if let json = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as? NSDictionary {
                    print(json)
                    
                    if let expiresDate = json["expires_date"] as? String {
                        
                    }
                    
                    if let processedTransactionIds = json["proccessed_transactions"] as? [String] {
                        
                    }
                    
                    
                }
                
            }
        }
        task.resume()
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
