//
//  CreateAccountVC.swift
//  JobShop
//
//  Created by Olivia Mates on 10/19/26.
//

import UIKit
import FirebaseCore
import FirebaseFirestore

class Account {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let pass: String
    let location: String
    let work: String
    let type: String
    let industry: String

}

class CreateAccountVC: UIViewController {

    let accountDB = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func step1Done(_ sender: Any) {
        
        let accountData: [String: Any] = [
                    "id": account.id,
                    "firstName": account.firstName,
                    "lastName": account.lastName,
                    "Email": account.email,
                    "Password": account.pass,
                    "CurrentLocation": account.location,
                    "WorkingLocations": account.work,
                    "JobTypes": account.type,
                    "IndustryTypes": account.industry,
                    
        ]
        
        accountDB.collection("accounts").document(account.id).setData(accountData) { error in
                    if let error = error {
                        print("Error saving entry: \(error.localizedDescription)")
                    } else {
                        print("Successfully saved multi-feature document!")
                    }
                }
    }
    



}
